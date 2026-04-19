import Foundation

struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var toolCallID: String?
    var toolName: String?
    var isRevealed: Bool

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = .now,
         toolCallID: String? = nil, toolName: String? = nil, isRevealed: Bool = true) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.isRevealed = isRevealed
    }

    enum MessageRole: String, Codable, Sendable {
        case user
        case assistant
        case system
        case toolResult
    }

    var isVisibleToUser: Bool {
        role == .user || role == .assistant
    }
}
