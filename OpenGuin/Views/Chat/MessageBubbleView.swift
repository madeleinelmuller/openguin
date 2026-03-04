import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            if message.role == .assistant {
                Image(systemName: "bird")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .glassEffect(GlassEffect.regular, in: .circle)
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
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LocalizedStringKey(message.content))
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                        if message.isStreaming {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(.primary.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                    .opacity(appeared ? 1 : 0.3)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: appeared)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                        }
                    }
                    .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 20))
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal, 4)
        .onAppear { appeared = true }
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
