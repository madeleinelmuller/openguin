import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    // MARK: - API Key Inputs
    var anthropicKeyInput: String = ""
    var openaiKeyInput: String = ""
    var customEndpointInput: String = ""
    var customModelNameInput: String = ""
    var anthropicCustomModelIDInput: String = ""
    var openAICustomModelIDInput: String = ""

    // MARK: - UI State
    var isAnthropicKeyVisible: Bool = false
    var isOpenAIKeyVisible: Bool = false
    var showClearConfirmation: Bool = false
    var showAPIKeySaved: Bool = false

    private let settings = SettingsManager.shared

    // MARK: - Provider Selection
    var selectedProvider: LLMProvider {
        get { settings.selectedProvider }
        set { settings.selectedProvider = newValue }
    }

    // MARK: - Anthropic Settings
    var selectedAnthropicModel: AnthropicModel {
        get { settings.selectedAnthropicModel }
        set { settings.selectedAnthropicModel = newValue }
    }

    // MARK: - OpenAI Settings
    var selectedOpenAIModel: OpenAIModel {
        get { settings.selectedOpenAIModel }
        set { settings.selectedOpenAIModel = newValue }
    }

    // MARK: - Custom Endpoint Settings
    var customEndpoint: String {
        get { settings.customEndpoint }
        set { settings.customEndpoint = newValue }
    }

    var customModelName: String {
        get { settings.customModelName }
        set { settings.customModelName = newValue }
    }

    var anthropicCustomModelID: String {
        get { settings.anthropicCustomModelID }
        set { settings.anthropicCustomModelID = newValue }
    }

    var openAICustomModelID: String {
        get { settings.openAICustomModelID }
        set { settings.openAICustomModelID = newValue }
    }

    // MARK: - Other Settings
    var hapticFeedbackEnabled: Bool {
        get { settings.hapticFeedbackEnabled }
        set { settings.hapticFeedbackEnabled = newValue }
    }

    // MARK: - Computed Properties
    var hasAPIKey: Bool {
        settings.hasValidAPIKey
    }

    var isUsingDevKey: Bool {
        settings.isUsingDevelopmentKey
    }

    var currentMaskedAPIKey: String {
        let key: String
        switch selectedProvider {
        case .anthropic:
            key = settings.effectiveAPIKey
        case .openai:
            key = settings.openaiAPIKey
        case .lmstudio:
            key = settings.customEndpoint
        }

        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    // MARK: - Methods
    func loadCurrentSettings() {
        anthropicKeyInput = settings.anthropicAPIKey
        openaiKeyInput = settings.openaiAPIKey
        customModelNameInput = settings.customModelName
        anthropicCustomModelIDInput = settings.anthropicCustomModelID
        openAICustomModelIDInput = settings.openAICustomModelID

        // For LMStudio: pre-populate the endpoint field with the default if none saved
        if settings.selectedProvider == .lmstudio && settings.customEndpoint.isEmpty {
            customEndpointInput = LLMProvider.lmstudio.defaultEndpoint
        } else {
            customEndpointInput = settings.customEndpoint
        }
    }

    func saveCurrentProvider() {
        switch selectedProvider {
        case .anthropic:
            let trimmed = anthropicKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelTrimmed = anthropicCustomModelIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.anthropicAPIKey = trimmed
            settings.anthropicCustomModelID = modelTrimmed
        case .openai:
            let trimmed = openaiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelTrimmed = openAICustomModelIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.openaiAPIKey = trimmed
            settings.openAICustomModelID = modelTrimmed
        case .lmstudio:
            let endpointTrimmed = customEndpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelTrimmed = customModelNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.customEndpoint = endpointTrimmed
            settings.customModelName = modelTrimmed
        }

        showAPIKeySaved = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showAPIKeySaved = false
        }
    }

    func clearCurrentProvider() {
        switch selectedProvider {
        case .anthropic:
            settings.anthropicAPIKey = ""
            settings.anthropicCustomModelID = ""
            anthropicKeyInput = ""
            anthropicCustomModelIDInput = ""
        case .openai:
            settings.openaiAPIKey = ""
            settings.openAICustomModelID = ""
            openaiKeyInput = ""
            openAICustomModelIDInput = ""
        case .lmstudio:
            settings.customEndpoint = ""
            settings.customModelName = ""
            customEndpointInput = ""
            customModelNameInput = ""
        }
    }

    func openProviderAuthURL() {
        if let url = selectedProvider.oauthURL {
            UIApplication.shared.open(url)
        }
    }

    func saveAnthropicCustomModelID() {
        settings.anthropicCustomModelID = anthropicCustomModelIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveOpenAICustomModelID() {
        settings.openAICustomModelID = openAICustomModelIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
