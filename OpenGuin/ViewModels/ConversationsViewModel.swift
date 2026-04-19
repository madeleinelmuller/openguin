import Foundation
import Observation

@Observable
@MainActor
final class ConversationsViewModel {
    private let store: ConversationStore

    var conversations: [Conversation] { store.conversations }

    init(store: ConversationStore) {
        self.store = store
    }

    func newConversation() -> Conversation {
        let settings = SettingsManager.shared
        return store.newConversation(providerID: settings.provider.rawValue)
    }

    func delete(_ conversation: Conversation) {
        store.delete(conversation)
    }

    func deleteAll() {
        store.deleteAll()
    }
}
