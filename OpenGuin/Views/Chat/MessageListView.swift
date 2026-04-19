import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let activeToolName: String?

    @Namespace private var bottomAnchor

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Spacer at top so short conversations don't crowd the top
                    Color.clear.frame(height: 16)

                    ForEach(messages.filter(\.isVisibleToUser)) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // Tool activity indicator
                    if let tool = activeToolName {
                        ToolActivityView(toolName: tool)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Thinking indicator (streaming but no tool)
                    if isStreaming && activeToolName == nil &&
                        messages.filter(\.isVisibleToUser).last?.role != .assistant {
                        ThinkingBubbleView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Scroll anchor
                    Color.clear.frame(height: 8).id("bottom")
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: messages.count)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeToolName)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isStreaming)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: activeToolName) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isStreaming) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}
