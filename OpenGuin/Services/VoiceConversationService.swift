import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class VoiceConversationService: NSObject {
    static let shared = VoiceConversationService()

    var isListening: Bool = false
    var isSpeaking: Bool = false
    var transcriptPreview: String = ""
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private let kittenTTS = KittenTTSService.shared

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onFinalTranscript: ((String) -> Void)?
    private var shouldResumeListeningAfterSpeech: Bool = false

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func toggleListening(onFinalTranscript: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            Task {
                await startListening(onFinalTranscript: onFinalTranscript)
            }
        }
    }

    func startListening(onFinalTranscript: @escaping (String) -> Void) async {
        self.onFinalTranscript = onFinalTranscript
        errorMessage = nil

        let permissionGranted = await requestPermissionsIfNeeded()
        guard permissionGranted else {
            errorMessage = "Speech permissions are required for Voice (Experimental)."
            return
        }

        if isSpeaking {
            Task {
                await kittenTTS.stopSpeaking()
            }
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if audioEngine.isRunning {
            stopListening()
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is currently unavailable."
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
            transcriptPreview = ""
        } catch {
            errorMessage = "Could not start microphone: \(error.localizedDescription)"
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    self.transcriptPreview = result.bestTranscription.formattedString

                    if result.isFinal {
                        let finalText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.stopListening()
                        if !finalText.isEmpty {
                            self.onFinalTranscript?(finalText)
                        }
                    }
                }
            }

            if let error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        transcriptPreview = ""
    }

    func speak(_ text: String, restartListeningAfterFinish: Bool, onFinalTranscript: @escaping (String) -> Void) {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanText = cleanText.replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        stopListening()
        shouldResumeListeningAfterSpeech = restartListeningAfterFinish
        self.onFinalTranscript = onFinalTranscript
        isSpeaking = true

        Task {
            do {
                try await kittenTTS.speak(cleanText) { [weak self] in
                    Task { @MainActor in
                        self?.handleSpeechFinished()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Kitten voice failed, using system voice."
                }

                let utterance = AVSpeechUtterance(string: cleanText)
                utterance.rate = 0.5
                utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
                speechSynthesizer.speak(utterance)
            }
        }
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuth else { return false }

        let micAuth = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return micAuth
    }

    private func handleSpeechFinished() {
        isSpeaking = false
        guard shouldResumeListeningAfterSpeech, let onFinalTranscript else { return }
        shouldResumeListeningAfterSpeech = false
        Task {
            await startListening(onFinalTranscript: onFinalTranscript)
        }
    }
}

extension VoiceConversationService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleSpeechFinished()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.shouldResumeListeningAfterSpeech = false
        }
    }
}
