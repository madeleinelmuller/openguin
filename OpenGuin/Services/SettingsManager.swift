import Foundation
import Observation

@Observable
final class SettingsManager: @unchecked Sendable {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    var provider: LLMProvider {
        get { LLMProvider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .anthropic }
        set { defaults.set(newValue.rawValue, forKey: "provider") }
    }

    var model: String {
        get { defaults.string(forKey: "model") ?? provider.defaultModel }
        set { defaults.set(newValue, forKey: "model") }
    }

    var anthropicKey: String {
        get { defaults.string(forKey: "anthropicKey") ?? "" }
        set { defaults.set(newValue, forKey: "anthropicKey") }
    }

    var openAIKey: String {
        get { defaults.string(forKey: "openAIKey") ?? "" }
        set { defaults.set(newValue, forKey: "openAIKey") }
    }

    var ollamaEndpoint: String {
        get { defaults.string(forKey: "ollamaEndpoint") ?? "http://localhost:11434" }
        set { defaults.set(newValue, forKey: "ollamaEndpoint") }
    }

    var ollamaModel: String {
        get { defaults.string(forKey: "ollamaModel") ?? "llama3.2" }
        set { defaults.set(newValue, forKey: "ollamaModel") }
    }

    var lmStudioEndpoint: String {
        get { defaults.string(forKey: "lmStudioEndpoint") ?? "http://localhost:1234" }
        set { defaults.set(newValue, forKey: "lmStudioEndpoint") }
    }

    var lmStudioModel: String {
        get { defaults.string(forKey: "lmStudioModel") ?? "local-model" }
        set { defaults.set(newValue, forKey: "lmStudioModel") }
    }

    var userName: String {
        get { defaults.string(forKey: "userName") ?? "" }
        set { defaults.set(newValue, forKey: "userName") }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var maxTokens: Int {
        get { defaults.integer(forKey: "maxTokens").nonZero ?? 8192 }
        set { defaults.set(newValue, forKey: "maxTokens") }
    }

    func apiKey(for provider: LLMProvider) -> String {
        switch provider {
        case .anthropic: anthropicKey
        case .openAI: openAIKey
        case .ollama, .lmStudio: ""
        }
    }

    func endpoint(for provider: LLMProvider) -> String {
        switch provider {
        case .anthropic: "https://api.anthropic.com"
        case .openAI: "https://api.openai.com"
        case .ollama: ollamaEndpoint
        case .lmStudio: lmStudioEndpoint
        }
    }

    func activeModel(for provider: LLMProvider) -> String {
        switch provider {
        case .anthropic: model.isEmpty ? provider.defaultModel : model
        case .openAI: model.isEmpty ? provider.defaultModel : model
        case .ollama: ollamaModel
        case .lmStudio: lmStudioModel
        }
    }

    private init() {}
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
