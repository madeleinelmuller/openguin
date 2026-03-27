import SwiftUI

// MARK: - Animation Controller

/// Drives the send button animation state machine.
///
/// Image naming convention (add to xcassets or bundle):
///   Load frames:   load_001, load_002, load_003, …
///   Finish frames: finish_001, finish_002, finish_003, …
@Observable
@MainActor
private final class SendButtonController {

    enum Phase: Equatable {
        case opening    // plays finish sequence once at launch
        case idle       // holds on the last finish frame
        case ready      // shows arrow.up send icon
        case loading    // loops load frames
        case finishing  // plays finish sequence once after loading ends
    }

    private(set) var phase: Phase = .opening
    private(set) var frame: Int = 0

    var hasText: Bool = false { didSet { syncText() } }
    var isLoading: Bool = false { didSet { syncLoading() } }
    private(set) var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var pendingFinish = false
    private var timer: Timer?

    // MARK: - Frame data (loaded once, shared across all instances)

    static let loadFrames: [UIImage] = loadSequence(prefix: "load")
    static let finishFrames: [UIImage] = loadSequence(prefix: "finish")

    private static func loadSequence(prefix: String) -> [UIImage] {
        var result: [UIImage] = []
        var i = 1
        while let img = UIImage(named: String(format: "%@_%03d", prefix, i)) {
            result.append(img)
            i += 1
        }
        return result
    }

    // MARK: - Timing

    /// Playback rate. In low power mode every other frame is skipped but the
    /// timer fires at half the rate, so apparent animation speed stays the same.
    private var fps: Double { isLowPowerMode ? 15.0 : 30.0 }

    /// How many source frames to advance per tick. At 15 fps we skip one frame
    /// so the animation plays at full speed with half the rendering work.
    private var frameStep: Int { isLowPowerMode ? 2 : 1 }

    // MARK: - Lifecycle

    func start() {
        frame = 0
        phase = .opening
        startTimer()

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The closure is @Sendable; hop to MainActor to touch isolated state.
            Task { @MainActor [weak self] in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                if self?.timer != nil { self?.startTimer() }
            }
        }
    }

    // MARK: - State sync

    private func syncText() {
        switch phase {
        case .idle  where hasText:  phase = .ready
        case .ready where !hasText: phase = .idle
        default: break
        }
    }

    private func syncLoading() {
        if isLoading {
            phase = .loading
            frame = 0
            pendingFinish = false
            startTimer()
        } else {
            // Don't cut immediately – finish the current load loop first.
            pendingFinish = true
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            // Timer callback is @Sendable; hop to MainActor to touch isolated state.
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Tick

    private func tick() {
        switch phase {

        case .opening:
            advanceOnce(frames: Self.finishFrames) {
                self.phase = self.hasText ? .ready : .idle
            }

        case .loading:
            let count = Self.loadFrames.count
            guard count > 0 else { return }
            let next = frame + frameStep
            if next >= count {
                // Completed one full loop.
                frame = next % count
                if pendingFinish {
                    pendingFinish = false
                    phase = .finishing
                    frame = 0
                }
            } else {
                frame = next
            }

        case .finishing:
            advanceOnce(frames: Self.finishFrames) {
                self.phase = self.hasText ? .ready : .idle
            }

        case .idle, .ready:
            stopTimer()
        }
    }

    /// Advance one tick through a one-shot sequence; call `onComplete` and stop the timer when done.
    private func advanceOnce(frames: [UIImage], onComplete: () -> Void) {
        let count = frames.count
        if count == 0 {
            onComplete()
            stopTimer()
            return
        }
        let next = frame + frameStep
        if next >= count {
            frame = count - 1   // clamp to last frame
            onComplete()
            stopTimer()
        } else {
            frame = next
        }
    }
}

// MARK: - View

struct AnimatedSendButton: View {

    let hasText: Bool
    let isLoading: Bool
    let onSend: () -> Void

    @State private var ctrl = SendButtonController()

    var body: some View {
        Button {
            guard hasText, !isLoading else { return }
            onSend()
        } label: {
            frameContent
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(
            GlassEffect.regular
                .tint(hasText ? .blue.opacity(0.35) : .white.opacity(0.08))
                .interactive(),
            in: Circle()
        )
        .accessibilityLabel(hasText ? "Send message" : "Waiting")
        .onAppear   { ctrl.start() }
        .onChange(of: hasText)   { _, v in ctrl.hasText   = v }
        .onChange(of: isLoading) { _, v in ctrl.isLoading = v }
    }

    // MARK: Frame content

    @ViewBuilder
    private var frameContent: some View {
        switch ctrl.phase {

        case .opening, .finishing:
            sequenceImage(frames: SendButtonController.finishFrames, index: ctrl.frame)

        case .idle:
            // Hold on the last finish frame.
            if let last = SendButtonController.finishFrames.last {
                Image(uiImage: last)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                // Fallback when no images are bundled yet.
                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }

        case .ready:
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))

        case .loading:
            if !SendButtonController.loadFrames.isEmpty {
                sequenceImage(frames: SendButtonController.loadFrames, index: ctrl.frame)
            } else {
                // Fallback spinner when images aren't bundled yet.
                ProgressView()
                    .tint(.primary)
            }
        }
    }

    @ViewBuilder
    private func sequenceImage(frames: [UIImage], index: Int) -> some View {
        if !frames.isEmpty {
            Image(uiImage: frames[index % max(frames.count, 1)])
                .resizable()
                .scaledToFit()
                .padding(10)
        }
    }
}
