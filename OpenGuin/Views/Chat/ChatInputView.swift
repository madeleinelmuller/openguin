import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let isListening: Bool
    let isSpeaking: Bool
    let transcriptPreview: String
    let onSend: () -> Void
    let onToggleVoice: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        VStack(spacing: 10) {
            if isListening || !transcriptPreview.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: isListening ? "waveform.circle.fill" : "waveform.circle")
                        .foregroundStyle(isListening ? .green : .secondary)

                    Text(transcriptPreview.isEmpty ? "Listening…" : transcriptPreview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    onToggleVoice()
                } label: {
                    Image(systemName: isListening ? "stop.fill" : (isSpeaking ? "speaker.wave.2.fill" : "mic.fill"))
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    GlassEffect.regular
                        .tint(isListening ? .red.opacity(0.75) : .white.opacity(0.12))
                        .interactive(),
                    in: Circle()
                )

                TextField("Message openguin...", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .focused($isFocused)
                    // Don't auto-open the keyboard on launch.
                    .onAppear { isFocused = false }
                    .onSubmit {
                        if canSend { onSend() }
                    }
                    .glassEffect(GlassEffect.regular.interactive(), in: Capsule())

                AnimatedSendButton(
                    hasText: canSend,
                    isLoading: isLoading,
                    onSend: onSend
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
                isListening: false,
                isSpeaking: false,
                transcriptPreview: "",
                onSend: {},
                onToggleVoice: {}
            )
        }
    }
}
