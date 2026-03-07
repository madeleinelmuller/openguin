import AVFoundation
import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class KittenTTSService: NSObject {
    static let shared = KittenTTSService()

    var isPreparing = false
    var isReady = false
    var isSpeaking = false
    var errorMessage: String?
    var selectedVoiceID = "expr-voice-2-m"

    let webView: WKWebView

    private let fileManager = FileManager.default
    private let modelURL = URL(string: "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/model.onnx")!

    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var pendingPlaybackCompletion: (() -> Void)?

    private override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        configuration.userContentController = controller

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        controller.add(self, name: "kittenTTSBridge")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isHidden = true
    }

    func prepare() async throws {
        if isReady { return }
        if isPreparing {
            while isPreparing && !isReady {
                try await Task.sleep(for: .milliseconds(150))
            }
            return
        }

        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }

        let runtimeDirectory = try prepareRuntimeDirectory()
        try await ensureModelFiles(in: runtimeDirectory)
        try await loadRuntime(from: runtimeDirectory)
        try await installBridgeHelpers()
        try await waitForRuntimeReady()
        isReady = true
    }

    func speak(_ text: String, voiceID: String? = nil, onPlaybackFinished: (() -> Void)? = nil) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pendingPlaybackCompletion = onPlaybackFinished
        try await prepare()
        selectedVoiceID = voiceID ?? selectedVoiceID
        isSpeaking = true

        let payload = Self.jsonEscaped(trimmed)
        let voice = Self.jsonEscaped(selectedVoiceID)
        let js = "window.openguinKitten.speak(\(payload), \(voice));"
        _ = try await evaluate(js)
    }

    func stopSpeaking() async {
        pendingPlaybackCompletion = nil
        isSpeaking = false
        _ = try? await evaluate("window.openguinKitten && window.openguinKitten.stop();")
    }

    private func prepareRuntimeDirectory() throws -> URL {
        let supportRoot = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let runtimeDirectory = supportRoot.appendingPathComponent("KittenTTSWeb", isDirectory: true)

        if fileManager.fileExists(atPath: runtimeDirectory.path) {
            return runtimeDirectory
        }

        guard let bundledDirectory = bundledRuntimeDirectory() else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.copyItem(at: bundledDirectory, to: runtimeDirectory)
        return runtimeDirectory
    }

    private func bundledRuntimeDirectory() -> URL? {
        if let explicit = Bundle.main.resourceURL?.appendingPathComponent("KittenTTSWeb"),
           fileManager.fileExists(atPath: explicit.path) {
            return explicit
        }

        if let bundledIndex = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "KittenTTSWeb") {
            return bundledIndex.deletingLastPathComponent()
        }

        return nil
    }

    private func ensureModelFiles(in runtimeDirectory: URL) async throws {
        let modelDirectory = runtimeDirectory.appendingPathComponent("tts-model", isDirectory: true)
        try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let primaryModelURL = modelDirectory.appendingPathComponent("model.onnx")
        let fallbackModelURL = modelDirectory.appendingPathComponent("model_backup.onnx")

        if !fileManager.fileExists(atPath: primaryModelURL.path) {
            let (temporaryURL, _) = try await URLSession.shared.download(from: modelURL)
            if fileManager.fileExists(atPath: primaryModelURL.path) {
                try? fileManager.removeItem(at: primaryModelURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: primaryModelURL)
        }

        if !fileManager.fileExists(atPath: fallbackModelURL.path) {
            if fileManager.fileExists(atPath: fallbackModelURL.path) {
                try? fileManager.removeItem(at: fallbackModelURL)
            }
            try fileManager.copyItem(at: primaryModelURL, to: fallbackModelURL)
        }
    }

    private func loadRuntime(from runtimeDirectory: URL) async throws {
        let indexURL = runtimeDirectory.appendingPathComponent("index.html")
        guard fileManager.fileExists(atPath: indexURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        if webView.url == indexURL {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            navigationContinuation = continuation
            webView.loadFileURL(indexURL, allowingReadAccessTo: runtimeDirectory)
        }
    }

    private func installBridgeHelpers() async throws {
        _ = try await evaluate(Self.bridgeScript)
    }

    private func waitForRuntimeReady() async throws {
        for _ in 0..<120 {
            let result = try await evaluate("""
                (() => {
                    const button = [...document.querySelectorAll('button')].find((entry) => {
                        const label = (entry.innerText || '').trim();
                        return label === 'Generate' || label === 'Play';
                    });
                    const loading = document.body.innerText.includes('Loading model...');
                    return Boolean(button) && !loading;
                })();
                """)

            if let ready = result as? Bool, ready {
                return
            }

            try await Task.sleep(for: .milliseconds(250))
        }

        throw KittenTTSServiceError.runtimeReadyTimedOut
    }

    private struct AnySendable: @unchecked Sendable {
        let value: Any?
    }

    private func evaluate(_ script: String) async throws -> Any? {
        let box: AnySendable = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: AnySendable(value: result))
                }
            }
        }
        return box.value
    }

    private static func jsonEscaped(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let encoded = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(encoded.dropFirst().dropLast())
    }

    private static let bridgeScript = """
        (() => {
            if (window.openguinKitten) {
                return true;
            }

            const post = (payload) => {
                if (window.webkit?.messageHandlers?.kittenTTSBridge) {
                    window.webkit.messageHandlers.kittenTTSBridge.postMessage(payload);
                }
            };

            const findPlayButton = () => [...document.querySelectorAll('button')].find((entry) => {
                const label = (entry.innerText || '').trim();
                return label === 'Generate' || label === 'Play' || label === 'Pause';
            });

            let playbackPoll = null;

            const ensurePlaybackObservers = () => {
                const audios = [...document.querySelectorAll('audio')];
                audios.forEach((audio, index) => {
                    if (audio.dataset.openguinBound === 'true') {
                        return;
                    }

                    audio.dataset.openguinBound = 'true';
                    audio.addEventListener('ended', () => {
                        const remaining = [...document.querySelectorAll('audio')].some((entry) => !entry.ended);
                        if (!remaining) {
                            post({ type: 'playbackEnded' });
                        }
                    });
                    audio.addEventListener('error', () => {
                        post({ type: 'error', message: `Audio playback failed for chunk ${index}.` });
                    });
                });
            };

            const speak = (text, voiceID) => {
                const textarea = document.querySelector('textarea');
                const voiceSelect = document.querySelector('#voice-selector');
                const playButton = findPlayButton();

                if (!textarea || !voiceSelect || !playButton) {
                    post({ type: 'error', message: 'Kitten TTS controls were not found.' });
                    return false;
                }

                textarea.value = text;
                textarea.dispatchEvent(new Event('input', { bubbles: true }));

                voiceSelect.value = voiceID;
                voiceSelect.dispatchEvent(new Event('change', { bubbles: true }));

                const clickWhenReady = () => {
                    const button = findPlayButton();
                    if (!button) {
                        post({ type: 'error', message: 'Kitten TTS generate button disappeared.' });
                        return;
                    }

                    button.click();

                    if (playbackPoll) {
                        clearInterval(playbackPoll);
                    }

                    playbackPoll = setInterval(() => {
                        ensurePlaybackObservers();
                        const hasAudio = document.querySelectorAll('audio').length > 0;
                        const loading = document.body.innerText.includes('Loading model...');
                        if (hasAudio && !loading) {
                            clearInterval(playbackPoll);
                            playbackPoll = null;
                        }
                    }, 150);
                };

                window.setTimeout(clickWhenReady, 50);
                return true;
            };

            const stop = () => {
                [...document.querySelectorAll('audio')].forEach((audio) => {
                    audio.pause();
                    audio.currentTime = 0;
                });
                if (playbackPoll) {
                    clearInterval(playbackPoll);
                    playbackPoll = null;
                }
            };

            window.openguinKitten = { speak, stop };
            return true;
        })();
        """
}

extension KittenTTSService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
}

extension KittenTTSService: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "kittenTTSBridge" else { return }

        guard let payload = message.body as? [String: Any],
              let type = payload["type"] as? String else {
            return
        }

        switch type {
        case "playbackEnded":
            isSpeaking = false
            let completion = pendingPlaybackCompletion
            pendingPlaybackCompletion = nil
            completion?()
        case "error":
            isSpeaking = false
            errorMessage = payload["message"] as? String ?? "Kitten TTS failed."
        default:
            break
        }
    }
}

enum KittenTTSServiceError: LocalizedError {
    case runtimeReadyTimedOut

    var errorDescription: String? {
        switch self {
        case .runtimeReadyTimedOut:
            return "Kitten TTS took too long to become ready."
        }
    }
}
