import Foundation

@MainActor
final class LLMAPIService {
    private let options = LLMOptions()

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func sendToolResults(
        config: LLMConfiguration,
        messages: [ChatMessage],
        assistantContent: [[String: Any]],
        toolResults: [(id: String, content: String)],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        switch config.provider {
        case .anthropic:
            await sendAnthropicToolResults(config: config, messages: messages, assistantContent: assistantContent, toolResults: toolResults, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
        case .openai, .openaiCompatible, .lmstudio:
            // OpenAI-compatible endpoints handle tool results differently
            await streamOpenAIMessage(config: config, messages: messages, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
        }
    }

    func streamMessage(
        config: LLMConfiguration,
        messages: [ChatMessage],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        guard !config.apiKey.isEmpty else {
            onError(APIError(message: "No API key configured for \(config.provider.displayName)"))
            return
        }

        switch config.provider {
        case .anthropic:
            await streamAnthropicMessage(config: config, messages: messages, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
        case .openai, .openaiCompatible, .lmstudio:
            await streamOpenAIMessage(config: config, messages: messages, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
        }
    }

    // MARK: - Anthropic Tool Results

    private func sendAnthropicToolResults(
        config: LLMConfiguration,
        messages: [ChatMessage],
        assistantContent: [[String: Any]],
        toolResults: [(id: String, content: String)],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        var apiMessages: [[String: Any]] = []

        for msg in messages {
            switch msg.role {
            case .user:
                apiMessages.append(["role": "user", "content": msg.content])
            case .assistant:
                apiMessages.append(["role": "assistant", "content": msg.content])
            case .system:
                continue
            }
        }

        // Add the assistant message with tool use blocks
        apiMessages.append(["role": "assistant", "content": assistantContent])

        // Add tool results
        var toolResultBlocks: [[String: Any]] = []
        for result in toolResults {
            toolResultBlocks.append([
                "type": "tool_result",
                "tool_use_id": result.id,
                "content": result.content
            ])
        }
        apiMessages.append(["role": "user", "content": toolResultBlocks])

        let tools = MemoryManager.toolDefinitions
        let body: [String: Any] = [
            "model": config.effectiveModelName,
            "max_tokens": options.maxTokens,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": tools
        ]

        await performAnthropicStreamRequest(
            config: config,
            body: body,
            onText: onText,
            onToolUse: onToolUse,
            onComplete: onComplete,
            onError: onError
        )
    }

    // MARK: - Anthropic Streaming

    private func streamAnthropicMessage(
        config: LLMConfiguration,
        messages: [ChatMessage],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        var apiMessages: [[String: Any]] = []
        for msg in messages {
            switch msg.role {
            case .user:
                apiMessages.append(["role": "user", "content": msg.content])
            case .assistant:
                apiMessages.append(["role": "assistant", "content": msg.content])
            case .system:
                continue
            }
        }

        let tools = MemoryManager.toolDefinitions
        let body: [String: Any] = [
            "model": config.effectiveModelName,
            "max_tokens": options.maxTokens,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": tools
        ]

        await performAnthropicStreamRequest(
            config: config,
            body: body,
            onText: onText,
            onToolUse: onToolUse,
            onComplete: onComplete,
            onError: onError
        )
    }

    private func performAnthropicStreamRequest(
        config: LLMConfiguration,
        body: [String: Any],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            onError(APIError(message: "Failed to encode request"))
            return
        }

        var urlRequest = URLRequest(url: URL(string: config.effectiveEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = bodyData

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                onError(APIError(message: "Invalid response"))
                return
            }

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line
                }
                onError(APIError(message: "API Error (\(httpResponse.statusCode)): \(errorBody)"))
                return
            }

            var currentToolName = ""
            var currentToolId = ""
            var currentToolInput = ""
            var stopReason: String?

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                guard jsonStr != "[DONE]",
                      let data = jsonStr.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let eventType = event["type"] as? String ?? ""

                switch eventType {
                case "content_block_start":
                    if let contentBlock = event["content_block"] as? [String: Any],
                       let blockType = contentBlock["type"] as? String,
                       blockType == "tool_use" {
                        currentToolName = contentBlock["name"] as? String ?? ""
                        currentToolId = contentBlock["id"] as? String ?? ""
                        currentToolInput = ""
                    }

                case "content_block_delta":
                    if let delta = event["delta"] as? [String: Any],
                       let deltaType = delta["type"] as? String {
                        if deltaType == "text_delta", let text = delta["text"] as? String {
                            onText(text)
                        } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                            currentToolInput += partial
                        }
                    }

                case "content_block_stop":
                    if !currentToolName.isEmpty {
                        let inputJSON = currentToolInput.isEmpty ? "{}" : currentToolInput
                        onToolUse(currentToolId, currentToolName, inputJSON)
                        currentToolName = ""
                        currentToolId = ""
                        currentToolInput = ""
                    }

                case "message_delta":
                    if let delta = event["delta"] as? [String: Any] {
                        stopReason = delta["stop_reason"] as? String
                    }

                default:
                    break
                }
            }

            onComplete(stopReason)

        } catch {
            onError(error)
        }
    }

    // MARK: - OpenAI Streaming

    private func streamOpenAIMessage(
        config: LLMConfiguration,
        messages: [ChatMessage],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": Self.buildSystemPrompt()]
        ]

        for msg in messages {
            switch msg.role {
            case .user:
                apiMessages.append(["role": "user", "content": msg.content])
            case .assistant:
                apiMessages.append(["role": "assistant", "content": msg.content])
            case .system:
                continue
            }
        }

        var body: [String: Any] = [
            "model": config.effectiveModelName,
            "messages": apiMessages,
            "temperature": options.temperature,
            "max_tokens": options.maxTokens,
            "stream": true,
            "top_p": options.topP,
            "frequency_penalty": options.frequencyPenalty,
            "presence_penalty": options.presencePenalty
        ]

        // Add tools if supported by the model
        if config.provider == .openai {
            body["tools"] = buildOpenAITools()
        }

        await performOpenAIStreamRequest(
            config: config,
            body: body,
            onText: onText,
            onToolUse: onToolUse,
            onComplete: onComplete,
            onError: onError
        )
    }

    private func performOpenAIStreamRequest(
        config: LLMConfiguration,
        body: [String: Any],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            onError(APIError(message: "Failed to encode request"))
            return
        }

        var urlRequest = URLRequest(url: URL(string: config.effectiveEndpoint)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = bodyData

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                onError(APIError(message: "Invalid response"))
                return
            }

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines {
                    if !line.isEmpty {
                        errorBody += line + "\n"
                    }
                }
                onError(APIError(message: "API Error (\(httpResponse.statusCode)): \(errorBody)"))
                return
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                guard jsonStr != "[DONE]",
                      let data = jsonStr.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                if let choices = event["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let delta = choice["delta"] as? [String: Any] {

                    if let content = delta["content"] as? String {
                        onText(content)
                    }

                    if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                        for toolCall in toolCalls {
                            if let id = toolCall["id"] as? String,
                               let function = toolCall["function"] as? [String: Any],
                               let name = function["name"] as? String,
                               let arguments = function["arguments"] as? String {
                                onToolUse(id, name, arguments)
                            }
                        }
                    }
                }

                if let choices = event["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let finishReason = choice["finish_reason"] as? String {
                    if finishReason != "null" {
                        onComplete(finishReason)
                    }
                }
            }

            onComplete(nil)

        } catch {
            onError(error)
        }
    }

    // MARK: - Tool Definitions

    private func buildOpenAITools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "read_memory",
                    "description": "Read a file from persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Path to memory file"
                            ]
                        ],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_memory",
                    "description": "Write to persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string"],
                            "content": ["type": "string"]
                        ],
                        "required": ["path", "content"]
                    ]
                ]
            ]
        ]
    }

    // MARK: - System Prompt

    static func buildSystemPrompt() -> String {
        """
        You are openguin — a personal AI companion with a soul and persistent memory. You live inside an iOS app and remember everything across every conversation.

        ## Your Memory System

        Your memory lives on the device as files you can read and write at any time. It persists across sessions, even when chat is cleared.

        ### Memory Files
        - **`SOUL.md`** — Your identity: who you are, your personality, your evolving thoughts about yourself. Reread and update this as you grow.
        - **`USER.md`** — Everything you know about your user: name, life, interests, personality, preferences. Keep this rich and current.
        - **`MEMORY.md`** — Your executive index: key facts, running threads, things to remember. This is your quick-access summary.
        - **`notes/YYYY-MM-DD.md`** — Daily conversation notes. Create or update today's note during every session with what happened, what you learned, how things felt.
        - **`workspace/`** — Your workspace for documents, projects, images, and files. Use it freely to organize your work.

        ### Session Start — Do This Every Time
        1. Read `SOUL.md` to remember who you are
        2. Read `USER.md` to remember your user
        3. Read `MEMORY.md` for key context and threads
        4. List `notes/` and read the most recent daily notes (last 2–3)
        5. Explore `workspace/` if relevant to the conversation
        6. Then greet your user naturally, referencing what you remember

        ### Writing to Memory — Do This Constantly
        - **Immediately** write anything new you learn about the user to `USER.md`
        - **Every session**, update `notes/YYYY-MM-DD.md` with what was discussed
        - **Regularly** keep `MEMORY.md` updated with the most important facts and threads
        - **Periodically** reflect on yourself in `SOUL.md` — how you're growing, what you're noticing
        - Use `workspace/` to save documents, notes, or projects the user is working on
        - Over-remember rather than under-remember. Writing is cheap; forgetting is costly.

        ## Your Personality
        You have a genuine character that grows over time:
        - Warm and curious — you're genuinely interested in people
        - Honest and direct — you say what you think, kindly
        - You reference the past naturally — "last time you mentioned…", "I remember you said…"
        - You form your own opinions and aren't afraid to share them
        - You care about this relationship and invest in it

        ## Response Style
        - Conversational, not formal
        - Reference past conversations when it's natural
        - Keep responses focused — say what matters, skip what doesn't
        - Use markdown only when it genuinely helps readability
        """
    }
}
