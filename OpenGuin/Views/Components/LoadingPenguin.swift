import SwiftUI

// MARK: - Frame sequence loader

/// A reusable PNG-sequence animator. Frames are discovered from the
/// main bundle at init (avoids hardcoding counts — drop new frames into
/// `OpenGuin/Resources/Loading/` and they get picked up automatically).
private struct FrameSequence {
    let frames: [UIImage]

    init(prefix: String) {
        // Scan the main bundle for any `<prefix>_*.png`. Files live in
        // `OpenGuin/Resources/Loading/` and are flattened at the bundle root
        // by the file-system synchronized group.
        let urls = (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefix + "_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        self.frames = urls.compactMap { UIImage(contentsOfFile: $0.path) }
    }

    var count: Int { frames.count }
    func frame(at index: Int) -> UIImage? {
        guard !frames.isEmpty else { return nil }
        return frames[index % frames.count]
    }
}

/// Animates the uploaded openguin loading image sequence.
/// - While `isAnimating == true` plays the `load_*` loop.
/// - When `isAnimating` flips to `false` it plays the `finish_*` sequence
///   once, then holds the last frame.
struct LoadingPenguin: View {
    var size: CGFloat = 80
    var isAnimating: Bool = true
    /// Frames per second for the loop. The uploaded sequence was authored
    /// at ~30fps but sparsely sampled every 4 frames, so 12fps plays at
    /// roughly natural speed.
    var fps: Double = 14
    /// Called once when the finish sequence completes and the last frame is held.
    var onFinished: (() -> Void)? = nil

    @State private var loadSeq = FrameSequence(prefix: "load")
    @State private var finishSeq = FrameSequence(prefix: "finish")
    @State private var frameIndex: Int = 0
    @State private var mode: Mode = .loading
    @State private var pendingFinish: Bool = false
    @State private var timer: Timer?

    private enum Mode { case loading, finishing, done }

    var body: some View {
        Group {
            if let img = currentImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                // Fallback if PNGs didn't bundle — keep the app usable.
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            startTicking()
            // If launched with isAnimating=false, immediately queue finish sequence
            // so it plays through a load loop then transitions to finish.
            if !isAnimating { pendingFinish = true }
        }
        .onDisappear { stopTicking() }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                // Resume / restart the loop cleanly.
                pendingFinish = false
                mode = .loading
                frameIndex = 0
                startTicking()
            } else {
                // Don't snap to the finish sequence — let the current loop
                // iteration complete, then transition.
                pendingFinish = true
            }
        }
    }

    private var currentImage: UIImage? {
        switch mode {
        case .loading:
            return loadSeq.frame(at: frameIndex)
        case .finishing:
            return finishSeq.frame(at: min(frameIndex, max(finishSeq.count - 1, 0)))
        case .done:
            return finishSeq.frames.last ?? loadSeq.frames.last
        }
    }

    private func startTicking() {
        stopTicking()
        guard fps > 0 else { return }
        let interval = 1.0 / fps
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in advance() }
        }
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        switch mode {
        case .loading:
            guard loadSeq.count > 0 else { return }
            let next = frameIndex + 1
            if next >= loadSeq.count {
                // End of a loop iteration — if a finish was requested
                // while we were looping, transition now.
                if pendingFinish {
                    pendingFinish = false
                    mode = .finishing
                    frameIndex = 0
                } else {
                    frameIndex = 0
                }
            } else {
                frameIndex = next
            }
        case .finishing:
            if finishSeq.count == 0 {
                mode = .done
                stopTicking()
                onFinished?()
                return
            }
            if frameIndex + 1 >= finishSeq.count {
                mode = .done
                stopTicking()
                onFinished?()
            } else {
                frameIndex += 1
            }
        case .done:
            stopTicking()
        }
    }
}

/// Celebratory one-shot of the finish sequence, used on the onboarding
/// complete screen. Plays once and rests on the last frame.
struct CelebrationPenguin: View {
    var size: CGFloat = 120

    @State private var finished = false

    var body: some View {
        LoadingPenguin(size: size, isAnimating: !finished, fps: 16)
            .onAppear {
                // Flip to finish sequence ~0.7s after appearance so the
                // intro plays, then settles.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    finished = true
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingPenguin(size: 120)
        CelebrationPenguin(size: 140)
    }
    .padding()
}
