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
        case .lmstudio: return "LMStudio"
        }
    }

    var description: String {
        switch self {
        case .anthropic: return "Claude - Most capable, with extended thinking"
        case .openai: return "GPT-4, GPT-3.5 - OpenAI's models"
        case .openaiCompatible: return "Any OpenAI-compatible endpoint"
        case .lmstudio: return "Local models via LMStudio"
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
        case .lmstudio: return "http://localhost:1234/v1/chat/completions"
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
    case haiku = "claude-3-5-haiku-20241022"
    case sonnet = "claude-3-5-sonnet-20241022"
    case opus = "claude-3-opus-20250219"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Claude 3.5 Haiku"
        case .sonnet: return "Claude 3.5 Sonnet"
        case .opus: return "Claude 3 Opus"
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

enum CustomModel: String, CaseIterable, Identifiable, Sendable {
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String { "Custom Model" }

    var description: String { "Enter your model name" }
}

// MARK: - Configuration Types

struct LLMConfiguration: Sendable {
    let provider: LLMProvider
    let apiKey: String
    let endpoint: String?
    let modelId: String
    let customModelName: String?

    var effectiveEndpoint: String {
        endpoint ?? provider.defaultEndpoint
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
