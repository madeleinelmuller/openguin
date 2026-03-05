import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showNewChatConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                RainbowBlobsBackground()

                VStack(spacing: 0) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        Spacer()
                    } else {
                        messageListView
                    }

                    ChatInputView(
                        text: $viewModel.inputText,
                        isLoading: viewModel.isLoading,
                        onSend: { viewModel.sendMessage() }
                    )
                }
            }
            .navigationTitle("Chat")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if viewModel.messages.isEmpty {
                            return
                        }
                        showNewChatConfirm = true
                    } label: {
                        Image(systemName: "plus.message")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("New Chat", isPresented: $showNewChatConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    withAnimation(.smooth) {
                        viewModel.clearChat()
                    }
                }
            } message: {
                Text("Start a new conversation? Your memory will be preserved.")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
                if viewModel.errorMessage?.contains("API key") == true {
                    Button("Open Settings") {
                        NotificationCenter.default.post(name: .switchToSettings, object: nil)
                    }
                }
                Button("Retry") { viewModel.retryLastMessage() }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.smooth) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let switchToSettings = Notification.Name("switchToSettings")
}

#Preview {
    ChatView()
}
