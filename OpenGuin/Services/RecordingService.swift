import Foundation
import AVFoundation
import Speech
import ActivityKit

@Observable
@MainActor
final class RecordingService {
    static let shared = RecordingService()

    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var isTranscribing = false
    var transcriptionError: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var durationTask: Task<Void, Never>?
    private var recordingStartTime: Date?
    private var liveActivity: Activity<OpenGuinSharedTypes.RecordingAttributes>?

    private init() {}

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        // Microphone
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else { return false }

        // Speech recognition — check current status first to avoid
        // potential double-resume issues with requestAuthorization callback
        let currentSpeechStatus = SFSpeechRecognizer.authorizationStatus()
        switch currentSpeechStatus {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let granted = await withUnsafeContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            return granted
        @unknown default:
            return false
        }
    }

    // MARK: - Recording

    func startRecording() async -> Bool {
        guard !isRecording else { return false }

        let granted = await requestPermissions()
        guard granted else {
            transcriptionError = "Microphone or speech recognition permission denied. Please enable in Settings."
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let tempDir = FileManager.default.temporaryDirectory
            let url = tempDir.appendingPathComponent("recording-\(UUID().uuidString).m4a")
            recordingURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()

            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0
            transcriptionError = nil

            // Start Live Activity
            startLiveActivity()

            // Duration tracking using a Task loop (actor-safe, no @Sendable closure)
            durationTask?.cancel()
            durationTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, self.isRecording, let start = self.recordingStartTime else { break }
                    self.recordingDuration = Date().timeIntervalSince(start)
                    self.updateLiveActivity()
                }
            }

            return true
        } catch {
            transcriptionError = "Failed to start recording: \(error.localizedDescription)"
            return false
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        durationTask?.cancel()
        durationTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return recordingURL
    }

    // MARK: - Transcription

    func transcribeRecording(at url: URL) async -> String? {
        isTranscribing = true
        updateLiveActivity()

        defer {
            isTranscribing = false
            endLiveActivity()
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            transcriptionError = "Speech recognition is not available on this device."
            return nil
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        do {
            // recognitionTask calls its handler multiple times (partial results
            // + final). Use nonisolated(unsafe) flag to track whether the
            // continuation has already been resumed, preventing a crash.
            let transcript: String = try await withCheckedThrowingContinuation { continuation in
                nonisolated(unsafe) var hasResumed = false
                recognizer.recognitionTask(with: request) { result, error in
                    guard !hasResumed else { return }
                    if let error {
                        hasResumed = true
                        continuation.resume(throwing: error)
                    } else if let result, result.isFinal {
                        hasResumed = true
                        let text = result.bestTranscription.formattedString
                        continuation.resume(returning: text)
                    }
                }
            }

            // Clean up recording file
            try? FileManager.default.removeItem(at: url)

            if transcript.isEmpty {
                transcriptionError = "No speech was detected in the recording."
                return nil
            }

            return transcript
        } catch {
            transcriptionError = "Transcription failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Stops recording, transcribes, and returns the transcript text.
    func stopAndTranscribe() async -> String? {
        guard let url = stopRecording() else { return nil }
        return await transcribeRecording(at: url)
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Live Activities

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = OpenGuinSharedTypes.RecordingAttributes(sessionName: "Recording")
        let state = OpenGuinSharedTypes.RecordingAttributes.ContentState(duration: 0, isTranscribing: false)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            liveActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            print("[RecordingService] Failed to start Live Activity: \(error)")
            liveActivity = nil
        }
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = OpenGuinSharedTypes.RecordingAttributes.ContentState(
            duration: recordingDuration,
            isTranscribing: isTranscribing
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await liveActivity.update(content)
        }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }
        let state = OpenGuinSharedTypes.RecordingAttributes.ContentState(
            duration: recordingDuration,
            isTranscribing: false
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await liveActivity.end(content, dismissalPolicy: .immediate)
        }
        self.liveActivity = nil
    }
}

