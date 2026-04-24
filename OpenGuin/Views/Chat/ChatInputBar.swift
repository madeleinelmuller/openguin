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
    @State private var bounceArrow = false
    @State private var dotPulse = false

    private let lightGen  = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let rigidGen  = UIImpactFeedbackGenerator(style: .rigid)

    private enum InputPhase: Equatable {
        case idle, focused, typing, streaming, finishing, recording
    }

    private var phase: InputPhase {
        if isRecordingActive { return .recording }
        if isStreaming        { return .streaming }
        if isFinishing        { return .finishing }
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

    private let controlSize: CGFloat = 44

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassBody
            } else {
                fallbackBody
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: separated)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: phase)
        .onChange(of: isStreaming) { old, new in
            guard old && !new else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isFinishing = true }
        }
        .onChange(of: phase) { _, p in
            dotPulse = (p == .recording)
        }
    }

    // MARK: - iOS 26

    @available(iOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: separated ? 8 : 0) {
                pillContent
                    .glassEffect(.regular, in: Capsule())
                circleButton
                    .glassEffect(phase == .typing || phase == .recording ? .regular : .regular.interactive(),
                                 in: Circle())
            }
        }
    }

    private var fallbackBody: some View {
        HStack(alignment: .center, spacing: separated ? 8 : 0) {
            pillContent
                .background(.ultraThinMaterial, in: Capsule())
            circleButton
                .background(
                    (phase == .typing || phase == .recording)
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
        }
    }

    // MARK: - Pill

    private var pillContent: some View {
        HStack(spacing: 8) {
            if phase == .idle || phase == .focused || phase == .recording {
                Button(action: handleMicTap) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(phase == .recording ? Color.red : Color.secondary)
                        .symbolEffect(.pulse, options: .repeating, isActive: phase == .recording)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .leading)))
            }

            if phase == .recording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotPulse ? 1.35 : 0.7)
                        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: dotPulse)
                    VoiceWaveformView(levels: recording.audioLevels)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 24)
                .transition(.opacity)
            } else {
                TextField("Message Openguin…", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .focused($isFocused)
                    .disabled(phase == .streaming || phase == .finishing)
                    .opacity((phase == .streaming || phase == .finishing) ? 0.45 : 1.0)
                    .frame(minHeight: 24)
                    .onSubmit {
                        if hasText { handleSend() }
                    }
                    .transition(.opacity)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .frame(minHeight: controlSize)
    }

    // MARK: - Circle Button

    private var circleButton: some View {
        Button(action: handleCircleButtonTap) {
            ZStack {
                switch phase {
                case .idle, .focused:
                    penguinLogo
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                case .typing:
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, options: .nonRepeating, isActive: bounceArrow)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                case .streaming:
                    LoadingPenguin(size: 36, isAnimating: true, fps: 14)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                case .finishing:
                    LoadingPenguin(size: 36, isAnimating: false, fps: 14, onFinished: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isFinishing = false
                        }
                    })
                    .allowsHitTesting(false)
                    .transition(.opacity)
                case .recording:
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                }
            }
            .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
        .disabled(phase == .finishing)
    }

    @ViewBuilder
    private var penguinLogo: some View {
        if UIImage(named: "openguin") != nil {
            Image("openguin")
                .resizable()
                .scaledToFit()
                .padding(7)
        } else {
            Image(systemName: "bird.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        if phase == .recording {
            lightGen.impactOccurred()
            recording.cancelRecording()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isRecordingActive = false
            }
        } else {
            rigidGen.impactOccurred(intensity: 0.7)
            Task {
                try? await Task.sleep(for: .milliseconds(80))
                await MainActor.run { rigidGen.impactOccurred(intensity: 1.0) }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
        case .idle, .focused:
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isRecordingActive = false
                    }
                    if let t = transcript, !t.isEmpty {
                        text = t
                        handleSend()
                    }
                }
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
