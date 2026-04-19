import Foundation

enum LLMProvider: String, CaseIterable, Codable, Sendable, Identifiable {
    case anthropic
    case openAI
    case ollama
    case lmStudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-sonnet-4-6"
        case .openAI: "gpt-4o"
        case .ollama: "llama3.2"
        case .lmStudio: "local-model"
        }
    }

    var availableModels: [String] {
        switch self {
        case .anthropic:
            return ["claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
        case .openAI:
            return ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"]
        case .ollama:
            return ["llama3.2", "llama3.1", "mistral", "qwen2.5", "deepseek-r1"]
        case .lmStudio:
            return ["local-model"]
        }
    }

    var isOpenAICompatible: Bool {
        switch self {
        case .anthropic: false
        case .openAI, .ollama, .lmStudio: true
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .anthropic: "https://api.anthropic.com"
        case .openAI: "https://api.openai.com"
        case .ollama: "http://localhost:11434"
        case .lmStudio: "http://localhost:1234"
        }
    }

    var chatPath: String {
        switch self {
        case .anthropic: "/v1/messages"
        case .openAI: "/v1/chat/completions"
        case .ollama: "/v1/chat/completions"
        case .lmStudio: "/v1/chat/completions"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .anthropic, .openAI: true
        case .ollama, .lmStudio: false
        }
    }
}
