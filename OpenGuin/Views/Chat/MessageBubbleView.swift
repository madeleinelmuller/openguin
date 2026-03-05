import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .user {
                    Text(message.content)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(
                            GlassEffect.regular.tint(.blue),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                } else {
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 20))
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal, 4)
    }
}

#Preview {
    ZStack {
        RainbowBlobsBackground()

        VStack(spacing: 12) {
            MessageBubbleView(message: ChatMessage(role: .user, content: "Hello there!"))
            MessageBubbleView(message: ChatMessage(role: .assistant, content: "Hi! I'm openguin. How can I help you today?"))
        }
        .padding()
    }
}
