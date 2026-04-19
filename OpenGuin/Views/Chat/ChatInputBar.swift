import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onMicTap: () -> Void
    let onCancelStream: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Mic button
            HapticButton(.light, action: onMicTap) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .adaptiveGlass(.interactive, shape: Circle())
            }

            // Text field
            TextField("Message Openguin…", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .font(.body)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSend()
                }

            // Send / cancel button
            if isStreaming {
                HapticButton(.medium, action: onCancelStream) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor, in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                HapticButton(.light, action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.secondary.opacity(0.3)
                                : Color.accentColor,
                            in: Circle()
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isStreaming)
    }
}

#Preview {
    @Previewable @State var text = ""
    ChatInputBar(
        text: $text,
        isStreaming: false,
        onSend: {},
        onMicTap: {},
        onCancelStream: {}
    )
}
