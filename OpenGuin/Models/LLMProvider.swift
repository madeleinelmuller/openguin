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

    /// Does this provider have a user-editable endpoint field?
    /// (Cloud providers are pinned; local-runner providers are not.)
    var hasCustomEndpoint: Bool {
        switch self {
        case .anthropic, .openAI: false
        case .ollama, .lmStudio: true
        }
    }

    /// Human hint shown under the endpoint input.
    var endpointHint: String {
        switch self {
        case .ollama: "Default: localhost:11434"
        case .lmStudio: "Default: localhost:1234"
        case .anthropic, .openAI: ""
        }
    }
}

// MARK: - Endpoint normalization

extension LLMProvider {
    /// Turn raw user input into a usable base URL string.
    ///
    /// Rules:
    /// - Empty or whitespace → provider default
    /// - Missing scheme and looks like `host[:port][/path]` → prepend `http://`
    ///   (local providers default to http; cloud providers default to https)
    /// - Strip any `/v1` or `/v1/...` suffix the user may have pasted so we
    ///   can append `chatPath` without double-prefixing
    /// - Strip trailing slashes
    func normalizedEndpoint(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return defaultEndpoint }

        // Add scheme if missing. Accept `localhost:11434`, `192.168.1.5:1234`,
        // `my.server.internal`, etc.
        var withScheme = trimmed
        if !withScheme.lowercased().hasPrefix("http://"),
           !withScheme.lowercased().hasPrefix("https://") {
            let scheme = (self == .ollama || self == .lmStudio) ? "http" : "https"
            withScheme = "\(scheme)://\(withScheme)"
        }

        // Split scheme from the rest so we can work on the path portion.
        guard let schemeRange = withScheme.range(of: "://") else {
            return withScheme
        }
        let schemePart = String(withScheme[..<schemeRange.upperBound])
        var rest = String(withScheme[schemeRange.upperBound...])

        // Strip trailing slashes
        while rest.hasSuffix("/") { rest.removeLast() }

        // Strip any /v1 or /v1/... the user may have included — we always
        // append `chatPath` (which starts with /v1) ourselves.
        let lower = rest.lowercased()
        if let v1Range = lower.range(of: "/v1", options: [.backwards]),
           v1Range.upperBound == lower.endIndex || lower[v1Range.upperBound] == "/" {
            rest = String(rest[..<v1Range.lowerBound])
        }

        // Strip any lingering trailing slashes after /v1 removal
        while rest.hasSuffix("/") { rest.removeLast() }

        return schemePart + rest
    }
}
