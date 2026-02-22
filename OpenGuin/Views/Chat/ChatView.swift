import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showNewChatConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated rainbow background
                AnimatedRainbowBackground()

                VStack(spacing: 0) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyStateView
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
            .navigationTitle("openguin")
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
                        // Post notification to switch to settings tab
                        NotificationCenter.default.post(name: .switchToSettings, object: nil)
                    }
                }
                Button("Retry") { viewModel.retryLastMessage() }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .onAppear {
                viewModel.loadMemoryOnStart()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            GlassEffectContainer {
                VStack(spacing: 16) {
                    Image("OpenGuinIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .glassEffect(.regular, in: .circle)

                    Text("openguin")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your AI assistant with persistent memory")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages.filter { !($0.content.isEmpty && $0.isStreaming) }) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if let last = viewModel.messages.last, last.isStreaming && last.content.isEmpty {
                        TypingIndicatorView()
                            .id("typing")
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
            .onChange(of: viewModel.messages.last?.content) {
                proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: sin(phase + Double(i) * 0.8) * 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
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
