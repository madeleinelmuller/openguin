import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void

    @FocusState private var isFocused: Bool
    @Namespace private var inputNamespace

    private var recording: RecordingService { RecordingService.shared }
    private var isActive: Bool { recording.isRecording || recording.isTranscribing }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {

                // MARK: Record / Stop button (left — always present)
                Button {
                    if isActive {
                        onStopRecording()
                    } else {
                        onStartRecording()
                    }
                } label: {
                    recordButtonIcon
                        .frame(width: 36, height: 36)
                }
                .disabled(recording.isTranscribing)
                .glassEffect(
                    GlassEffect.regular
                        .tint(isActive ? .red.opacity(0.3) : .red.opacity(0.15))
                        .interactive(),
                    in: .circle
                )
                .glassEffectID("recordButton", in: inputNamespace)

                // MARK: Center pill — text field OR merged visualization+send
                if isActive {
                    // Visualization bar + timer merged with the send button inside one pill
                    HStack(spacing: 10) {
                        // Timer
                        timerLabel

                        // Waveform visualization
                        AudioVisualizerView(levels: recording.audioLevels)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)

                        // Send button fused into the bar
                        sendStopIcon
                            .frame(width: 30, height: 30)
                            .padding(.trailing, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(
                        GlassEffect.regular.tint(.red.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                    .glassEffectID("sendButton", in: inputNamespace)
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .push(from: .leading).combined(with: .opacity)
                    ))
                } else {
                    // Normal text field
                    TextField("Message openguin...", text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .focused($isFocused)
                        .onSubmit {
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading {
                                onSend()
                            }
                        }
                        .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 22))
                        .transition(.asymmetric(
                            insertion: .push(from: .leading).combined(with: .opacity),
                            removal: .push(from: .trailing).combined(with: .opacity)
                        ))

                    // Send button (right — only visible when not recording)
                    Button {
                        onSend()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .glassEffect(
                        GlassEffect.regular
                            .tint(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                                  ? .gray : .blue)
                            .interactive(),
                        in: .circle
                    )
                    .glassEffectID("sendButton", in: inputNamespace)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.smooth(duration: 0.35), value: isActive)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var recordButtonIcon: some View {
        if recording.isTranscribing {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.red)
        } else if recording.isRecording {
            // Pulsing filled dot-in-circle = actively recording, tap to stop
            Image(systemName: "record.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)
        } else {
            Image(systemName: "record.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    private var timerLabel: some View {
        Text(recording.isTranscribing ? "…" : recording.formattedDuration)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundStyle(.red)
            .monospacedDigit()
            .frame(minWidth: 42, alignment: .leading)
    }

    @ViewBuilder
    private var sendStopIcon: some View {
        if recording.isTranscribing {
            ProgressView()
                .scaleEffect(0.65)
                .tint(.secondary)
        } else {
            // Arrow-up in the merged bar = stop recording + send transcript
            Image(systemName: "arrow.up")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.red.opacity(0.8))
        }
    }
}

// MARK: - Audio Visualizer

private struct AudioVisualizerView: View {
    let levels: [Float]

    private let totalBars = 25

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let barWidth = max(2, (geo.size.width - CGFloat(totalBars - 1) * spacing) / CGFloat(totalBars))
            let maxBarHeight = geo.size.height - 4
            let displayLevels = Array(levels.suffix(totalBars))
            let padCount = max(0, totalBars - displayLevels.count)

            HStack(alignment: .center, spacing: spacing) {
                // Pad left with quiet bars when buffer isn't full yet
                ForEach(0..<padCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: barWidth, height: 3)
                }
                ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                    let height = max(3, CGFloat(level) * maxBarHeight + 3)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.red.opacity(0.5 + Double(level) * 0.5))
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    ZStack {
        RainbowBlobsBackground()
        VStack {
            Spacer()
            ChatInputView(
                text: .constant("Hello"),
                isLoading: false,
                onSend: {},
                onStartRecording: {},
                onStopRecording: {}
            )
        }
    }
}
