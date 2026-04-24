import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - User bubble

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(.white)
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .accentColor.opacity(0.25), radius: 8, y: 4)
            .contextMenu { copyButton }
    }

    // MARK: - Assistant bubble

    private var assistantBubble: some View {
        RevealingText(text: message.content, isRevealed: message.isRevealed)
            .font(.body)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .contextMenu { copyButton }
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = message.content
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 8) {
            MessageBubbleView(message: ChatMessage(role: .user, content: "Hey, what's the weather like?"))
            MessageBubbleView(message: ChatMessage(role: .assistant, content: "Let me check that for you! It looks like it's going to be a beautiful day — sunny with highs around 72°F.", isRevealed: true))
        }
        .padding(.vertical)
    }
}
