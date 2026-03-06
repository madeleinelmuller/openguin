import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.content.isEmpty {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.blue.opacity(0.25))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                )
        } else if message.content.isEmpty {
            TypingDotsView()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        } else {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Typing Dots

struct TypingDotsView: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.primary.opacity(i == activeIndex ? 0.7 : 0.25))
                    .frame(width: 8, height: 8)
                    .scaleEffect(i == activeIndex ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: activeIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}

#Preview {
    ZStack {
        RainbowBlobsBackground()
        VStack(spacing: 12) {
            MessageBubbleView(message: ChatMessage(role: .user, content: "Hello there!"))
            MessageBubbleView(message: ChatMessage(role: .assistant, content: "Hi! I'm openguin. How can I help you today?"))
            MessageBubbleView(message: ChatMessage(role: .assistant, content: ""))
        }
        .padding()
    }
}
