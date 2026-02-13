import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var apiKeyInput: String = ""
    var isAPIKeyVisible: Bool = false
    var showClearConfirmation: Bool = false
    var showAPIKeySaved: Bool = false

    private let settings = SettingsManager.shared

    var selectedModel: ClaudeModel {
        get { settings.selectedModel }
        set { settings.selectedModel = newValue }
    }

    var hapticFeedbackEnabled: Bool {
        get { settings.hapticFeedbackEnabled }
        set { settings.hapticFeedbackEnabled = newValue }
    }

    var hasAPIKey: Bool {
        settings.hasValidAPIKey
    }

    var isUsingDevKey: Bool {
        settings.isUsingDevelopmentKey
    }

    var maskedAPIKey: String {
        let key = settings.effectiveAPIKey
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }

    func loadCurrentKey() {
        apiKeyInput = settings.apiKey
    }

    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.apiKey = trimmed
        showAPIKeySaved = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            showAPIKeySaved = false
        }
    }

    func clearAPIKey() {
        settings.apiKey = ""
        apiKeyInput = ""
    }
}
