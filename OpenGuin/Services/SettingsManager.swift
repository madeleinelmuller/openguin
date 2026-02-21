import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let apiKeyKey = "anthropic_api_key"
    private let modelKey = "selected_model"
    private let hapticKey = "haptic_feedback"

    var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
        }
    }

    var selectedModel: ClaudeModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: modelKey)
        }
    }

    var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: hapticKey)
        }
    }

    var hasValidAPIKey: Bool {
        !effectiveAPIKey.isEmpty
    }

    /// Returns the API key to use: user-set key takes priority, then env fallback
    var effectiveAPIKey: String {
        if !apiKey.isEmpty {
            return apiKey
        }
        return Self.developmentAPIKey
    }

    /// Development API key from environment (set in Xcode scheme)
    nonisolated private static let developmentAPIKey: String = {
        ProcessInfo.processInfo.environment["API_KEY"] ?? ""
    }()

    var isUsingDevelopmentKey: Bool {
        apiKey.isEmpty && !Self.developmentAPIKey.isEmpty
    }

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
        let modelRaw = UserDefaults.standard.string(forKey: modelKey) ?? ClaudeModel.sonnet.rawValue
        self.selectedModel = ClaudeModel(rawValue: modelRaw) ?? .sonnet
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: hapticKey) as? Bool ?? true
    }
}

enum ClaudeModel: String, CaseIterable, Identifiable, Sendable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-6"
    case opus = "claude-opus-4-6"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Claude Haiku 4.5"
        case .sonnet: return "Claude Sonnet 4.6"
        case .opus: return "Claude Opus 4.6"
        }
    }

    var description: String {
        switch self {
        case .haiku: return "Fast & efficient"
        case .sonnet: return "Balanced performance"
        case .opus: return "Most capable"
        }
    }
}
