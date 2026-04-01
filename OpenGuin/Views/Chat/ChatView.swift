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
                        onSend: { viewModel.sendMessage() },
                        onStartRecording: { viewModel.startMeetingRecording() },
                        onStopRecording: { viewModel.stopMeetingRecording() }
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
                            .transition(
                                message.role == .assistant
                                    ? .asymmetric(
                                        insertion: .scale(scale: 0.92, anchor: .bottomLeading)
                                            .combined(with: .opacity),
                                        removal: .opacity
                                      )
                                    : .asymmetric(
                                        insertion: .scale(scale: 0.92, anchor: .bottomTrailing)
                                            .combined(with: .opacity),
                                        removal: .opacity
                                      )
                            )
                    }

                    // Loading bubble — shows while agent is thinking / using tools
                    if viewModel.isLoading {
                        TypingIndicatorView()
                            .id("loading")
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9, anchor: .bottomLeading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewModel.isLoading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    if viewModel.isLoading {
                        proxy.scrollTo("loading", anchor: .bottom)
                    } else {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.35 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 20))

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .onAppear {
            // Kick off the cascade by toggling phase repeatedly
            phase = 0
            withAnimation { phase = 1 }
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
