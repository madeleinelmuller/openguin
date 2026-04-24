import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let recording: RecordingService
    let onSend: () -> Void
    let onCancelStream: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isRecordingActive = false
    @State private var isFinishing = false
    @State private var introPlaying = true
    @State private var bounceArrow = false
    @State private var dotPulse = false

    private let lightGen  = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let rigidGen  = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: - Phase

    private enum InputPhase: Equatable {
        case intro, idle, focused, typing, streaming, finishing, recording
    }

    private var phase: InputPhase {
        if isRecordingActive { return .recording }
        if isStreaming        { return .streaming }
        if isFinishing        { return .finishing }
        if introPlaying       { return .intro }
        if hasText            { return .typing }
        if isFocused          { return .focused }
        return .idle
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var separated: Bool {
        switch phase {
        case .typing, .streaming, .finishing, .recording: return true
        default: return false
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassBody
            } else {
                fallbackBody
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: separated)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: phase)
        .onChange(of: isStreaming) { old, new in
            guard old && !new else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isFinishing = true }
        }
        .onChange(of: phase) { _, p in
            dotPulse = (p == .recording)
        }
    }

    // MARK: - iOS 26 Liquid Glass Body

    @available(iOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer {
            HStack(alignment: .bottom, spacing: separated ? 8 : 0) {
                pillContent
                    .glassEffect(.regular, in: Capsule())
                    .scaleEffect(isFocused ? 1.006 : 1.0, anchor: .bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isFocused)

                circleButton26
            }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var circleButton26: some View {
        switch phase {
        case .typing, .recording:
            solidCircleButton
        default:
            Button { handleCircleButtonTap() } label: {
                circleContent.frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .allowsHitTesting(phase != .finishing && phase != .intro)
        }
    }

    // MARK: - iOS <26 Fallback Body

    private var fallbackBody: some View {
        HStack(alignment: .bottom, spacing: separated ? 8 : 0) {
            pillContent
                .background(.ultraThinMaterial, in: Capsule())

            if phase == .typing || phase == .recording {
                solidCircleButton
            } else {
                Button { handleCircleButtonTap() } label: {
                    circleContent
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(phase == .finishing || phase == .intro)
            }
        }
    }

    private var solidCircleButton: some View {
        Button { handleCircleButtonTap() } label: {
            circleContent
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pill Content

    private var pillContent: some View {
        HStack(spacing: 8) {
            // Mic button — visible in idle, focused, intro, recording
            if phase == .idle || phase == .focused || phase == .intro || phase == .recording {
                Button { handleMicTap() } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(phase == .recording ? .red : .secondary)
                        .symbolEffect(.pulse, options: .repeating, isActive: phase == .recording)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .leading)))
            }

            // Main field: waveform when recording, text field otherwise
            if phase == .recording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotPulse ? 1.35 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                            value: dotPulse
                        )

                    VoiceWaveformView(levels: recording.audioLevels)
                        .frame(maxWidth: .infinity)
                }
                .transition(.blurReplace)
            } else {
                TextField("Message Openguin…", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .focused($isFocused)
                    .disabled(phase == .streaming || phase == .finishing || phase == .intro)
                    .opacity((phase == .streaming || phase == .finishing) ? 0.45 : 1.0)
                    .animation(.spring(response: 0.3), value: phase)
                    .onSubmit {
                        guard hasText else { return }
                        handleSend()
                    }
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
    }

    // MARK: - Circle Content

    @ViewBuilder
    private var circleContent: some View {
        ZStack {
            if phase == .idle || phase == .focused {
                Image("openguin")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            if phase == .intro {
                LoadingPenguin(size: 36, isAnimating: false, fps: 14, onFinished: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        introPlaying = false
                    }
                })
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if phase == .typing {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: bounceArrow)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }

            if phase == .streaming {
                LoadingPenguin(size: 36, isAnimating: true, fps: 14)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if phase == .finishing {
                LoadingPenguin(size: 36, isAnimating: false, fps: 14, onFinished: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isFinishing = false
                    }
                })
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if phase == .recording {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
            }
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        if phase == .recording {
            lightGen.impactOccurred()
            recording.cancelRecording()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isRecordingActive = false
            }
        } else {
            rigidGen.impactOccurred(intensity: 0.7)
            Task {
                try? await Task.sleep(for: .milliseconds(80))
                await MainActor.run { rigidGen.impactOccurred(intensity: 1.0) }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isRecordingActive = true
            }
            Task {
                await recording.startRecording()
                if case .failed = recording.state {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isRecordingActive = false
                        }
                    }
                }
            }
        }
    }

    private func handleCircleButtonTap() {
        switch phase {
        case .idle, .focused, .intro:
            lightGen.impactOccurred()
            isFocused = true

        case .typing:
            mediumGen.impactOccurred()
            bounceArrow = true
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await MainActor.run { bounceArrow = false }
            }
            handleSend()

        case .streaming:
            rigidGen.impactOccurred()
            onCancelStream()

        case .recording:
            mediumGen.impactOccurred()
            Task {
                let transcript = await recording.stopAndTranscribe()
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isRecordingActive = false
                    }
                    if let t = transcript, !t.isEmpty {
                        text = t
                        handleSend()
                    }
                }
                try? await Task.sleep(for: .milliseconds(60))
                await MainActor.run { lightGen.impactOccurred() }
            }

        case .finishing:
            break
        }
    }

    private func handleSend() {
        guard hasText else { return }
        onSend()
    }
}
