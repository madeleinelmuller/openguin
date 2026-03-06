import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - Provider Settings Keys
    private let providerKey = "llm_provider"
    private let anthropicKeyKey = "anthropic_api_key"
    private let openaiKeyKey = "openai_api_key"
    private let customEndpointKey = "custom_endpoint"
    private let customModelNameKey = "custom_model_name"
    private let anthropicCustomModelIDKey = "anthropic_custom_model_id"
    private let openaiCustomModelIDKey = "openai_custom_model_id"

    // MARK: - Model Selection Keys
    private let anthropicModelKey = "anthropic_model"
    private let openaiModelKey = "openai_model"

    // MARK: - Other Settings Keys
    private let hapticKey = "haptic_feedback"

    // MARK: - Provider & API Keys
    var selectedProvider: LLMProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: providerKey)
        }
    }

    var anthropicAPIKey: String {
        didSet {
            UserDefaults.standard.set(anthropicAPIKey, forKey: anthropicKeyKey)
        }
    }

    var openaiAPIKey: String {
        didSet {
            UserDefaults.standard.set(openaiAPIKey, forKey: openaiKeyKey)
        }
    }

    var customEndpoint: String {
        didSet {
            UserDefaults.standard.set(customEndpoint, forKey: customEndpointKey)
        }
    }

    var customModelName: String {
        didSet {
            UserDefaults.standard.set(customModelName, forKey: customModelNameKey)
        }
    }

    var anthropicCustomModelID: String {
        didSet {
            UserDefaults.standard.set(anthropicCustomModelID, forKey: anthropicCustomModelIDKey)
        }
    }

    var openAICustomModelID: String {
        didSet {
            UserDefaults.standard.set(openAICustomModelID, forKey: openaiCustomModelIDKey)
        }
    }

    // MARK: - Model Selection
    var selectedAnthropicModel: AnthropicModel {
        didSet {
            UserDefaults.standard.set(selectedAnthropicModel.rawValue, forKey: anthropicModelKey)
        }
    }

    var selectedOpenAIModel: OpenAIModel {
        didSet {
            UserDefaults.standard.set(selectedOpenAIModel.rawValue, forKey: openaiModelKey)
        }
    }

    // MARK: - Other Settings
    var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: hapticKey)
        }
    }

    // MARK: - Computed Properties
    var effectiveAPIKey: String {
        switch selectedProvider {
        case .anthropic:
            return anthropicAPIKey.isEmpty ? Self.developmentAPIKey : anthropicAPIKey
        case .openai:
            return openaiAPIKey
        case .lmstudio:
            return "lmstudio" // LMStudio doesn't require authentication
        }
    }

    var hasValidAPIKey: Bool {
        switch selectedProvider {
        case .anthropic:
            return !effectiveAPIKey.isEmpty
        case .openai:
            return !openaiAPIKey.isEmpty
        case .lmstudio:
            return true // Always valid — falls back to default localhost:1234 endpoint
        }
    }

    var isUsingDevelopmentKey: Bool {
        selectedProvider == .anthropic && anthropicAPIKey.isEmpty && !Self.developmentAPIKey.isEmpty
    }

    var currentLLMConfiguration: LLMConfiguration {
        let apiKey: String
        let modelId: String
        let customModelName: String?

        switch selectedProvider {
        case .anthropic:
            apiKey = effectiveAPIKey
            modelId = anthropicCustomModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? selectedAnthropicModel.rawValue
                : anthropicCustomModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            customModelName = nil
        case .openai:
            apiKey = openaiAPIKey
            modelId = openAICustomModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? selectedOpenAIModel.rawValue
                : openAICustomModelID.trimmingCharacters(in: .whitespacesAndNewlines)
            customModelName = nil
        case .lmstudio:
            apiKey = "lmstudio" // LMStudio doesn't need real auth; any non-empty value passes guard
            customModelName = self.customModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : self.customModelName.trimmingCharacters(in: .whitespacesAndNewlines)
            modelId = customModelName ?? "local-model"
        }

        return LLMConfiguration(
            provider: selectedProvider,
            apiKey: apiKey,
            endpoint: customEndpoint.isEmpty ? nil : customEndpoint,
            modelId: modelId,
            customModelName: customModelName
        )
    }

    /// Development API key from environment (set in Xcode scheme)
    nonisolated private static let developmentAPIKey: String = {
        ProcessInfo.processInfo.environment["API_KEY"] ?? ""
    }()

    private init() {
        let providerRaw = UserDefaults.standard.string(forKey: providerKey) ?? LLMProvider.anthropic.rawValue
        if providerRaw == "openaiCompatible" {
            self.selectedProvider = .openai
        } else {
            self.selectedProvider = LLMProvider(rawValue: providerRaw) ?? .anthropic
        }

        self.anthropicAPIKey = UserDefaults.standard.string(forKey: anthropicKeyKey) ?? ""
        self.openaiAPIKey = UserDefaults.standard.string(forKey: openaiKeyKey) ?? ""
        self.customEndpoint = UserDefaults.standard.string(forKey: customEndpointKey) ?? ""
        self.customModelName = UserDefaults.standard.string(forKey: customModelNameKey) ?? ""
        self.anthropicCustomModelID = UserDefaults.standard.string(forKey: anthropicCustomModelIDKey) ?? ""
        self.openAICustomModelID = UserDefaults.standard.string(forKey: openaiCustomModelIDKey) ?? ""

        let anthropicModelRaw = UserDefaults.standard.string(forKey: anthropicModelKey) ?? AnthropicModel.sonnet46.rawValue
        self.selectedAnthropicModel = AnthropicModel(rawValue: anthropicModelRaw) ?? .sonnet46

        let openaiModelRaw = UserDefaults.standard.string(forKey: openaiModelKey) ?? OpenAIModel.gpt4turbo.rawValue
        self.selectedOpenAIModel = OpenAIModel(rawValue: openaiModelRaw) ?? .gpt4turbo

        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: hapticKey) as? Bool ?? true
    }
}
