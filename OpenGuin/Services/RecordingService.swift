import Foundation
import AVFoundation
import Speech
import Observation

enum RecordingState {
    case idle
    case recording
    case transcribing
    case done(String)
    case failed(String)

    var description: String {
        switch self {
        case .idle: "idle"
        case .recording: "recording"
        case .transcribing: "transcribing"
        case .done: "done"
        case .failed: "failed"
        }
    }
}

@Observable
@MainActor
final class RecordingService {
    var state: RecordingState = .idle
    var audioLevels: [Float] = Array(repeating: 0, count: 30)

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    func requestPermissions() async -> Bool {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { return false }

        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        return speechGranted
    }

    func startRecording() async {
        guard await requestPermissions() else {
            state = .failed("Microphone or speech recognition permission denied.")
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            state = .failed("Could not start audio session: \(error.localizedDescription)")
            return
        }

        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("openguin_recording.m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            state = .recording
            startLevelMonitoring()
        } catch {
            state = .failed("Could not start recording: \(error.localizedDescription)")
        }
    }

    func stopAndTranscribe() async -> String? {
        stopLevelMonitoring()
        recorder?.stop()
        state = .transcribing

        guard let url = recordingURL else {
            state = .failed("No recording found.")
            return nil
        }

        try? AVAudioSession.sharedInstance().setActive(false)

        let result = await transcribe(url: url)
        switch result {
        case .success(let text):
            state = .done(text)
            return text
        case .failure(let error):
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func cancelRecording() {
        stopLevelMonitoring()
        recorder?.stop()
        recorder = nil
        state = .idle
        audioLevels = Array(repeating: 0, count: 30)
    }

    private func transcribe(url: URL) async -> Result<String, Error> {
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            return .failure(NSError(domain: "RecordingService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available."]))
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(returning: .failure(error))
                } else if let result = result, result.isFinal {
                    cont.resume(returning: .success(result.bestTranscription.formattedString))
                }
            }
        }
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLevels()
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevels = Array(repeating: 0, count: 30)
    }

    private func updateLevels() {
        recorder?.updateMeters()
        guard let recorder = recorder else { return }
        let raw = recorder.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (raw + 60) / 60))
        audioLevels.removeFirst()
        audioLevels.append(normalized)
    }
}
