import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var voiceService = VoiceConversationService.shared
    @State private var kittenTTS = KittenTTSService.shared
    @State private var showNewChatConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                RainbowBlobsBackground()
                KittenTTSHostView(webView: kittenTTS.webView)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        Spacer()
                    } else {
                        messageListView
                    }

                    ChatInputView(
                        text: $viewModel.inputText,
                        isLoading: viewModel.isLoading,
                        isListening: voiceService.isListening,
                        isSpeaking: voiceService.isSpeaking || kittenTTS.isSpeaking,
                        transcriptPreview: voiceService.transcriptPreview,
                        onSend: { viewModel.sendMessage() },
                        onToggleVoice: { toggleVoiceMode() }
                    )
                }
            }
            .navigationTitle("Chat")
            .toolbarTitleDisplayMode(.inline)
            .onChange(of: viewModel.lastCompletedAssistantResponse) {
                guard viewModel.shouldSpeakNextAssistantReply,
                      let response = viewModel.lastCompletedAssistantResponse
                else { return }

                viewModel.shouldSpeakNextAssistantReply = false
                voiceService.speak(response, restartListeningAfterFinish: true) { transcript in
                    viewModel.sendVoiceMessage(transcript)
                }
            }
            .onChange(of: voiceService.errorMessage) {
                if let message = voiceService.errorMessage, !message.isEmpty {
                    viewModel.errorMessage = message
                    viewModel.showError = true
                }
            }
            .onChange(of: kittenTTS.errorMessage) {
                if let message = kittenTTS.errorMessage, !message.isEmpty {
                    viewModel.errorMessage = message
                    viewModel.showError = true
                }
            }
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
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.smooth) {
            if let lastId = viewModel.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func toggleVoiceMode() {
        voiceService.toggleListening { transcript in
            viewModel.sendVoiceMessage(transcript)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let switchToSettings = Notification.Name("switchToSettings")
    static let openChatFromNotification = Notification.Name("openChatFromNotification")
}

#Preview {
    ChatView()
}
