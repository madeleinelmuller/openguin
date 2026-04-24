import SwiftUI

struct ConversationsView: View {
    let vm: ConversationsViewModel
    let currentConversationID: UUID
    let onSelect: (Conversation) -> Void
    let onNew: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.conversations.isEmpty {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a new conversation to get going.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.conversations) { conversation in
                                conversationRow(conversation)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton(.light, action: onNew) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func conversationRow(_ conversation: Conversation) -> some View {
        let isSelected = conversation.id == currentConversationID

        Button {
            onSelect(conversation)
        } label: {
            ConversationRowView(
                conversation: conversation,
                isSelected: isSelected
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .adaptiveGlass(
                isSelected ? .interactive : .regular,
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    vm.delete(conversation)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Press scale effect

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
