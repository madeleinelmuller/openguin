import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void

    @FocusState private var isFocused: Bool
    @Namespace private var inputNamespace

    // Observe RecordingService directly for live state
    private var recording: RecordingService { RecordingService.shared }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if recording.isRecording || recording.isTranscribing {
                recordingBar
            } else {
                normalBar
            }
        }
    }

    // MARK: - Normal Input Bar

    private var normalBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Meeting recording button (aligned with bar)
            Button {
                onStartRecording()
            } label: {
                Image(systemName: "record.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
            }
            .glassEffect(
                GlassEffect.regular.tint(.red.opacity(0.15)).interactive(),
                in: .circle
            )
            .glassEffectID("recordButton", in: inputNamespace)

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
                    .tint(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : .blue)
                    .interactive(),
                in: .circle
            )
            .glassEffectID("sendButton", in: inputNamespace)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Recording Bar (merged send button with Liquid Glass)

    private var recordingBar: some View {
        HStack(alignment: .center, spacing: 12) {
            // Red pulsing dot + time
            HStack(spacing: 6) {
                if recording.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.blue)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(recording.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                   value: recording.isRecording)
                }

                Text(recording.isTranscribing ? "Transcribing…" : recording.formattedDuration)
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(recording.isTranscribing ? .secondary : .red)
                    .monospacedDigit()
            }
            .frame(minWidth: 72, alignment: .leading)

            // Audio level visualization (last 5 seconds)
            AudioVisualizerView(levels: recording.audioLevels)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 10))

            // Stop / send button (merged send button with recording state)
            Button {
                onStopRecording()
            } label: {
                Group {
                    if recording.isTranscribing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "stop.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .disabled(recording.isTranscribing)
            .glassEffect(
                GlassEffect.regular
                    .tint(recording.isTranscribing ? .gray : .red)
                    .interactive(),
                in: .circle
            )
            .glassEffectID("sendButton", in: inputNamespace)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .transition(.asymmetric(
            insertion: .push(from: .bottom).combined(with: .opacity),
            removal: .push(from: .top).combined(with: .opacity)
        ))
    }
}

// MARK: - Audio Visualizer

private struct AudioVisualizerView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                let barCount = min(levels.count, 25)
                let displayLevels = levels.suffix(barCount)
                let barWidth = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(max(barCount, 1)))

                ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                    let height = max(3, CGFloat(level) * (geo.size.height - 6) + 3)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.red.opacity(0.6 + Double(level) * 0.4))
                        .frame(width: barWidth, height: height)
                }

                // Fill remaining space with idle bars if buffer not full yet
                if displayLevels.count < barCount || levels.isEmpty {
                    ForEach(0..<max(0, 25 - displayLevels.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.red.opacity(0.2))
                            .frame(width: barWidth, height: 3)
                    }
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
