import SwiftUI

struct ChatView: View {
    @State var vm: ChatViewModel
    @State private var showConversations = false
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            MessageListView(
                messages: vm.conversation.messages,
                isStreaming: vm.isStreaming,
                activeToolName: vm.activeToolName
            )
            .background(Color.black)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputBar(
                    text: $vm.inputText,
                    isStreaming: vm.isStreaming,
                    recording: env.recording,
                    onSend: { vm.sendMessage() },
                    onCancelStream: { vm.cancelStreaming() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .navigationTitle(vm.conversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HapticButton(.light, action: { showConversations.toggle() }) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: { vm.clearConversation() }) {
                            Label("Clear conversation", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showConversations) {
                ConversationsView(
                    vm: ConversationsViewModel(store: env.conversationStore),
                    currentConversationID: vm.conversation.id,
                    onSelect: { conversation in
                        vm = ChatViewModel(conversation: conversation, store: env.conversationStore)
                        showConversations = false
                    },
                    onNew: {
                        let conv = env.conversationStore.newConversation(providerID: SettingsManager.shared.provider.rawValue)
                        vm = ChatViewModel(conversation: conv, store: env.conversationStore)
                        showConversations = false
                    }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
}
