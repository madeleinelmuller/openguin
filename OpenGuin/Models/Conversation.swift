import Foundation

struct Conversation: Identifiable, Codable, Sendable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var providerID: String

    init(id: UUID = UUID(), title: String = "New conversation",
         messages: [ChatMessage] = [], providerID: String = "") {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = .now
        self.updatedAt = .now
        self.providerID = providerID
    }

    var lastMessage: ChatMessage? {
        messages.filter(\.isVisibleToUser).last
    }

    var preview: String {
        lastMessage?.content.prefix(80).description ?? "No messages yet"
    }

    mutating func updateTitle() {
        if let first = messages.first(where: { $0.role == .user }) {
            title = String(first.content.prefix(50))
        }
    }
}
