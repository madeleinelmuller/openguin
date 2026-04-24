import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let settings: SettingsManager

    var provider: LLMProvider {
        get { settings.provider }
        set { settings.provider = newValue }
    }

    var model: String {
        get { settings.activeModel(for: settings.provider) }
        set { settings.setActiveModel(newValue, for: settings.provider) }
    }

    var anthropicKey: String {
        get { settings.anthropicKey }
        set { settings.anthropicKey = newValue }
    }

    var openAIKey: String {
        get { settings.openAIKey }
        set { settings.openAIKey = newValue }
    }

    var ollamaEndpoint: String {
        get { settings.ollamaEndpoint }
        set { settings.ollamaEndpoint = newValue }
    }

    var lmStudioEndpoint: String {
        get { settings.lmStudioEndpoint }
        set { settings.lmStudioEndpoint = newValue }
    }

    var userName: String {
        get { settings.userName }
        set { settings.userName = newValue }
    }

    var maxTokens: Int {
        get { settings.maxTokens }
        set { settings.maxTokens = newValue }
    }

    init(settings: SettingsManager = .shared) {
        self.settings = settings
    }
}
