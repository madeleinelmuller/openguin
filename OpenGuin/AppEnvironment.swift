import Foundation
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let settings = SettingsManager.shared
    let conversationStore = ConversationStore()
    let recording = RecordingService()

    static let shared = AppEnvironment()
    private init() {}
}
