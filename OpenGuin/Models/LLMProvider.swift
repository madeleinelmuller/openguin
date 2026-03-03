import Foundation

// MARK: - Provider Types

enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case anthropic
    case openai
    case openaiCompatible
    case lmstudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI"
        case .openaiCompatible: return "OpenAI Compatible"
        case .lmstudio: return "LM Studio"
        }
    }

    var description: String {
        switch self {
        case .anthropic: return "Claude - Most capable, with extended thinking"
        case .openai: return "GPT-4, GPT-3.5 - OpenAI's models"
        case .openaiCompatible: return "Any OpenAI-compatible endpoint"
        case .lmstudio: return "Local models via LM Studio"
        }
    }

    var requiresCustomEndpoint: Bool {
        self == .openaiCompatible || self == .lmstudio
    }

    var defaultEndpoint: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .openaiCompatible: return "http://localhost:8000/v1/chat/completions"
        case .lmstudio: return "http://localhost:1234/api/v1/chat"
        }
    }

    var supportsOAuth: Bool {
        self == .anthropic || self == .openai
    }

    var oauthURL: URL? {
        switch self {
        case .anthropic:
            return URL(string: "https://console.anthropic.com")
        case .openai:
            return URL(string: "https://platform.openai.com/account/api-keys")
        default:
            return nil
        }
    }
}

// MARK: - Model Types

enum AnthropicModel: String, CaseIterable, Identifiable, Sendable {
    case haiku45 = "claude-haiku-4-5"
    case sonnet46 = "claude-sonnet-4-6"
    case opus46 = "claude-opus-4-6"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku45: return "Claude Haiku 4.5"
        case .sonnet46: return "Claude Sonnet 4.6"
        case .opus46: return "Claude Opus 4.6"
        }
    }

    var description: String {
        switch self {
        case .haiku45: return "Fast & efficient"
        case .sonnet46: return "Latest balanced flagship"
        case .opus46: return "Highest capability"
        }
    }
}

enum OpenAIModel: String, CaseIterable, Identifiable, Sendable {
    case gpt4turbo = "gpt-4-turbo"
    case gpt4 = "gpt-4"
    case gpt35turbo = "gpt-3.5-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4turbo: return "GPT-4 Turbo"
        case .gpt4: return "GPT-4"
        case .gpt35turbo: return "GPT-3.5 Turbo"
        }
    }

    var description: String {
        switch self {
        case .gpt4turbo: return "Most capable"
        case .gpt4: return "Highly capable"
        case .gpt35turbo: return "Fast & efficient"
        }
    }
}

enum VoiceMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case kittenTTSMicro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .kittenTTSMicro: return "Kitten TTS Micro"
        }
    }

    var description: String {
        switch self {
        case .off: return "Text-only chat"
        case .kittenTTSMicro: return "Local TTS via mlx-community/kitten-tts-micro-0.8-6bit"
        }
    }

    var ttsModelIdentifier: String? {
        switch self {
        case .off: return nil
        case .kittenTTSMicro: return "mlx-community/kitten-tts-micro-0.8-6bit"
        }
    }
}

// MARK: - Configuration Types

struct LLMConfiguration: Sendable {
    let provider: LLMProvider
    let apiKey: String
    let endpoint: String?
    let modelId: String
    let customModelName: String?

    var effectiveEndpoint: String {
        let base = endpoint ?? provider.defaultEndpoint
        if provider == .lmstudio {
            return Self.normalizeLMStudioEndpoint(base)
        }
        return base
    }

    var effectiveModelName: String {
        customModelName ?? modelId
    }
}

struct LLMOptions: Sendable {
    let temperature: Double = 0.7
    let maxTokens: Int = 4096
    let topP: Double = 1.0
    let frequencyPenalty: Double = 0.0
    let presencePenalty: Double = 0.0
}

extension LLMConfiguration {
    fileprivate static func normalizeLMStudioEndpoint(_ endpoint: String) -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return trimmed }

        let path = components.path.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty || path == "/" {
            components.path = "/api/v1/chat/completions"
            return components.string ?? trimmed
        }

        if path.hasSuffix("/completions") {
            return components.string ?? trimmed
        }

        components.path = path.hasSuffix("/") ? "\(path)completions" : "\(path)/completions"
        return components.string ?? trimmed
    }
}
