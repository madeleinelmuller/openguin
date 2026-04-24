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

    /// Legacy single model key — kept only so reads of previously-saved
    /// `model` still work. New code should use per-provider storage.
    private var legacyModel: String? {
        defaults.string(forKey: "model")
    }

    var anthropicModel: String {
        get {
            if let stored = defaults.string(forKey: "anthropicModel") { return stored }
            // Migrate from legacy shared key if it looks like an Anthropic model
            if let legacy = legacyModel, legacy.hasPrefix("claude") { return legacy }
            return LLMProvider.anthropic.defaultModel
        }
        set { defaults.set(newValue, forKey: "anthropicModel") }
    }

    var openAIModel: String {
        get {
            if let stored = defaults.string(forKey: "openAIModel") { return stored }
            // Migrate from legacy shared key if it looks like an OpenAI model
            if let legacy = legacyModel, legacy.hasPrefix("gpt") || legacy.hasPrefix("o1") || legacy.hasPrefix("o3") {
                return legacy
            }
            return LLMProvider.openAI.defaultModel
        }
        set { defaults.set(newValue, forKey: "openAIModel") }
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
        case .anthropic: anthropicModel
        case .openAI: openAIModel
        case .ollama: ollamaModel
        case .lmStudio: lmStudioModel
        }
    }

    func setActiveModel(_ value: String, for provider: LLMProvider) {
        switch provider {
        case .anthropic: anthropicModel = value
        case .openAI: openAIModel = value
        case .ollama: ollamaModel = value
        case .lmStudio: lmStudioModel = value
        }
    }

    private init() {}
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
