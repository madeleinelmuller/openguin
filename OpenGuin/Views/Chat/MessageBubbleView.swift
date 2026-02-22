import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var appeared = false
    @State private var streamPulse = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            if message.role == .assistant {
                // Avatar
                Image(systemName: "bird")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: .circle)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .user {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    GlassEffectContainer {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(parsedSegments) { segment in
                                    if segment.isThinking {
                                        ThinkingSegmentView(text: segment.content, isStreaming: message.isStreaming)
                                    } else {
                                        Text(LocalizedStringKey(segment.content))
                                            .font(.body)
                                            .textSelection(.enabled)
                                            .opacity(message.isStreaming ? 0.94 : 1.0)
                                            .blur(radius: message.isStreaming ? (streamPulse ? 0.0 : 0.35) : 0)
                                            .animation(.easeInOut(duration: 0.22), value: message.content)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            if message.isStreaming {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(.primary.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .opacity(appeared ? 1 : 0.3)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(), value: appeared)
                                }
                                .padding(.trailing, 16)
                                .padding(.bottom, 8)
                            }
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    }
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                streamPulse = true
            }
        }
    }

    private var parsedSegments: [MessageSegment] {
        MessageSegment.parse(from: message.content)
    }
}

private struct MessageSegment: Identifiable {
    let id = UUID()
    let content: String
    let isThinking: Bool

    static func parse(from content: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        var cursor = content.startIndex

        while let openRange = content.range(of: "<think>", range: cursor..<content.endIndex) {
            if openRange.lowerBound > cursor {
                let normal = String(content[cursor..<openRange.lowerBound])
                if !normal.isEmpty { segments.append(.init(content: normal, isThinking: false)) }
            }

            let thoughtStart = openRange.upperBound
            if let closeRange = content.range(of: "</think>", range: thoughtStart..<content.endIndex) {
                let thought = String(content[thoughtStart..<closeRange.lowerBound])
                segments.append(.init(content: thought, isThinking: true))
                cursor = closeRange.upperBound
            } else {
                let thought = String(content[thoughtStart..<content.endIndex])
                segments.append(.init(content: thought, isThinking: true))
                cursor = content.endIndex
            }
        }

        if cursor < content.endIndex {
            let remainder = String(content[cursor..<content.endIndex])
            if !remainder.isEmpty { segments.append(.init(content: remainder, isThinking: false)) }
        }

        return segments.isEmpty ? [.init(content: content, isThinking: false)] : segments
    }
}

private struct ThinkingSegmentView: View {
    let text: String
    let isStreaming: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                Text("Thinking")
                HStack(spacing: 3) {
                    ForEach(0..<3) { i in
                        Circle()
                            .frame(width: 4, height: 4)
                            .offset(y: isStreaming ? sin(phase + CGFloat(i) * 0.8) * 1.8 : 0)
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(0.86)
                    .blur(radius: isStreaming ? 0.25 : 0)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 12) {
            MessageBubbleView(message: ChatMessage(role: .user, content: "Hello there!"))
            MessageBubbleView(message: ChatMessage(role: .assistant, content: "Hi! I'm openguin. How can I help you today?"))
        }
        .padding()
    }
}
