import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            messageList
            toolbar
            messageInput
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "message")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Start a conversation with your AI assistant")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .id("loadingIndicator")
                    }

                    if let error = viewModel.errorMessage, viewModel.showError {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Error")
                                    .font(.headline)
                                Spacer()
                            }
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(uiColor: .systemRed).opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(16)
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isLoading) {
                    if viewModel.isLoading {
                        withAnimation { proxy.scrollTo("loadingIndicator", anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.clearChat() }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }

            if !viewModel.messages.isEmpty {
                Button(action: { viewModel.retryLastMessage() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray6))
    }

    private var messageInput: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isLoading)
                .onSubmit { viewModel.sendMessage() }

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground))
    }

    private func messageBubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .foregroundColor(.white)
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(12)
                .background(Color.blue)
                .cornerRadius(16)
                .padding(.leading, 48)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .foregroundColor(.primary)
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(16)
                .padding(.trailing, 48)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ChatView()
}
