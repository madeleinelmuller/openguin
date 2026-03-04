import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    @FocusState private var isFocused: Bool
    @Namespace private var inputNamespace

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(alignment: .bottom, spacing: 10) {
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
