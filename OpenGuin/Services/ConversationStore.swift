import Foundation
import Observation

@Observable
@MainActor
final class ConversationStore {
    private(set) var conversations: [Conversation] = []
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("conversations.json")
        load()
    }

    func newConversation(providerID: String = "") -> Conversation {
        let conv = Conversation(providerID: providerID)
        conversations.insert(conv, at: 0)
        save()
        return conv
    }

    func update(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
            conversations[idx].updatedAt = .now
            save()
        }
    }

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        save()
    }

    func deleteAll() {
        conversations.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        conversations = (try? JSONDecoder().decode([Conversation].self, from: data)) ?? []
    }

    private func save() {
        try? JSONEncoder().encode(conversations).write(to: fileURL, options: .atomic)
    }
}
