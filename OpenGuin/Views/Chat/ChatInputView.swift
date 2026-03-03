import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    @State private var settings = SettingsManager.shared
    @State private var voiceService = VoiceConversationService.shared
    @FocusState private var isFocused: Bool
    @Namespace private var inputNamespace

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if settings.selectedVoiceMode != .off {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text("Voice (Experimental): \(settings.selectedVoiceMode.displayName)")
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Text field
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
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))

                if settings.selectedVoiceMode != .off {
                    Button {
                        voiceService.toggleListening { transcript in
                            text = transcript
                            onSend()
                        }
                    } label: {
                        Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }
                    .glassEffect(
                        .regular
                            .tint(voiceService.isListening ? .red : .purple)
                            .interactive(),
                        in: .circle
                    )
                }

                // Send button
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
                    .regular
                        .tint(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : .blue)
                        .interactive(),
                    in: .circle
                )
                .glassEffectID("sendButton", in: inputNamespace)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if settings.selectedVoiceMode != .off && (!voiceService.transcriptPreview.isEmpty || voiceService.errorMessage != nil) {
                Text(voiceService.errorMessage ?? "Heard: \(voiceService.transcriptPreview)")
                    .font(.caption)
                    .foregroundStyle(voiceService.errorMessage == nil ? .secondary : .red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
    }
}

#Preview {
    ZStack {
        RainbowBlobsBackground()

        VStack {
            Spacer()
            ChatInputView(text: .constant("Hello"), isLoading: false, onSend: {})
        }
    }
}
