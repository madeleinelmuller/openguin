import SwiftUI

struct ConversationsView: View {
    let vm: ConversationsViewModel
    let currentConversationID: UUID
    let onSelect: (Conversation) -> Void
    let onNew: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.conversations) { conversation in
                    Button {
                        onSelect(conversation)
                    } label: {
                        ConversationRowView(
                            conversation: conversation,
                            isSelected: conversation.id == currentConversationID
                        )
                    }
                    .listRowBackground(
                        conversation.id == currentConversationID
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        vm.delete(vm.conversations[idx])
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton(.light, action: onNew) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .overlay {
                if vm.conversations.isEmpty {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a new conversation to get going.")
                    )
                }
            }
        }
    }
}
