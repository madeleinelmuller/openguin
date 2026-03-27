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

    /// URL of the most recent raw audio recording.
    /// Present even when transcription fails, so the caller can offer a retry.
    private(set) var lastRecordingURL: URL?

    // MARK: - Private state

    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private let kittenTTS = KittenTTSService.shared

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onFinalTranscript: ((String) -> Void)?
    private var shouldResumeListeningAfterSpeech: Bool = false

    /// Text collected from completed recognition chunks.
    private var accumulatedTranscript: String = ""
    /// Set to true while we are restarting the recognition request mid-recording.
    /// Callbacks from the expiring task are suppressed during this window.
    private var isRestartingChunk: Bool = false
    /// Timer that restarts the recognition request before Apple's ~60 s limit.
    private var chunkTimer: Timer?

    /// AVAudioFile written in parallel with recognition so the raw audio is
    /// always saved regardless of whether transcription succeeds.
    private var audioSaveFile: AVAudioFile?

    // MARK: - Init

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Public API

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
        accumulatedTranscript = ""

        let permissionGranted = await requestPermissionsIfNeeded()
        guard permissionGranted else {
            errorMessage = "Speech permissions are required for Voice (Experimental)."
            return
        }

        if isSpeaking {
            Task { await kittenTTS.stopSpeaking() }
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if audioEngine.isRunning {
            stopListening()
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is currently unavailable."
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        // Open a file to save the raw audio alongside the live recognition.
        let saveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).caf")
        lastRecordingURL = saveURL
        audioSaveFile = try? AVAudioFile(forWriting: saveURL, settings: format.settings)

        // Create the first recognition request.
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // Single audio tap: feed both the recognizer and the save file.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            try? self?.audioSaveFile?.write(from: buffer)
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

        startRecognitionTask(with: request, recognizer: recognizer)

        // Restart recognition every 50 s to stay well inside Apple's ~60 s limit.
        chunkTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.restartRecognitionChunk() }
        }
    }

    func stopListening() {
        chunkTimer?.invalidate()
        chunkTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        audioSaveFile = nil   // flushes and closes the file

        isListening = false
        transcriptPreview = ""
        isRestartingChunk = false
    }

    // MARK: - Chunked recognition restart

    /// Called every 50 s to swap in a fresh recognition request before
    /// the current one times out.  The audio tap seamlessly switches to the
    /// new request because the tap closure always reads `self.recognitionRequest`.
    private func restartRecognitionChunk() {
        guard isListening,
              let recognizer = speechRecognizer,
              recognizer.isAvailable else { return }

        // Snapshot whatever text we have from this chunk.
        let partial = transcriptPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !partial.isEmpty {
            accumulatedTranscript += accumulatedTranscript.isEmpty ? partial : " \(partial)"
        }
        transcriptPreview = ""

        // Suppress callbacks from the expiring task.
        isRestartingChunk = true

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()

        // Fresh request – the tap closure picks it up automatically.
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        recognitionRequest = newRequest

        isRestartingChunk = false

        startRecognitionTask(with: newRequest, recognizer: recognizer)
    }

    /// Attach a recognition task to `request` and wire up the result/error callbacks.
    private func startRecognitionTask(
        with request: SFSpeechAudioBufferRecognitionRequest,
        recognizer: SFSpeechRecognizer
    ) {
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    guard !self.isRestartingChunk else { return }

                    self.transcriptPreview = result.bestTranscription.formattedString

                    if result.isFinal {
                        let chunkText = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        self.stopListening()

                        let full = [self.accumulatedTranscript, chunkText]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        if !full.isEmpty {
                            self.onFinalTranscript?(full)
                        }
                    }
                }
            }

            if let error {
                Task { @MainActor in
                    guard !self.isRestartingChunk else { return }
                    self.errorMessage = error.localizedDescription
                    self.stopListening()
                }
            }
        }
    }

    // MARK: - Retry transcription from saved file

    /// Re-transcribes the last saved audio recording using a file-based request.
    /// Useful when the live recognition failed but the audio was successfully saved.
    func retryTranscription(completion: @escaping (String?) -> Void) {
        guard let url = lastRecordingURL,
              FileManager.default.fileExists(atPath: url.path),
              let recognizer = speechRecognizer,
              recognizer.isAvailable
        else {
            completion(nil)
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result, result.isFinal {
                    completion(result.bestTranscription.formattedString)
                } else if error != nil {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Speech synthesis

    func speak(
        _ text: String,
        restartListeningAfterFinish: Bool,
        onFinalTranscript: @escaping (String) -> Void
    ) {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanText = cleanText
            .replacingOccurrences(of: "<think>", with: "")
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
                    Task { @MainActor in self?.handleSpeechFinished() }
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

    // MARK: - Permissions

    private func requestPermissionsIfNeeded() async -> Bool {
        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechAuth else { return false }

        let micAuth = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return micAuth
    }

    // MARK: - Helpers

    private func handleSpeechFinished() {
        isSpeaking = false
        guard shouldResumeListeningAfterSpeech, let onFinalTranscript else { return }
        shouldResumeListeningAfterSpeech = false
        Task { await startListening(onFinalTranscript: onFinalTranscript) }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceConversationService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.handleSpeechFinished() }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.shouldResumeListeningAfterSpeech = false
        }
    }
}
