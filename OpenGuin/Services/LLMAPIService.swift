import Foundation

@MainActor
final class LLMAPIService {
    private let options = LLMOptions()
    private struct PendingOpenAIToolCall {
        var id: String = ""
        var name: String = ""
        var arguments: String = ""
    }

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
        case .openai, .lmstudio:
            await sendOpenAIToolResults(
                config: config,
                messages: messages,
                assistantContent: assistantContent,
                toolResults: toolResults,
                onText: onText,
                onToolUse: onToolUse,
                onComplete: onComplete,
                onError: onError
            )
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
        case .openai, .lmstudio:
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

        guard let endpointURL = URL(string: config.effectiveEndpoint) else {
            onError(APIError(message: "Invalid endpoint URL: \(config.effectiveEndpoint)"))
            return
        }

        var urlRequest = URLRequest(url: endpointURL)
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
        let apiMessages = buildOpenAIMessages(from: messages)

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
        if config.provider == .openai || config.provider == .lmstudio {
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

    private func sendOpenAIToolResults(
        config: LLMConfiguration,
        messages: [ChatMessage],
        assistantContent: [[String: Any]],
        toolResults: [(id: String, content: String)],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        var apiMessages = buildOpenAIMessages(from: messages)

        let assistantText = assistantContent
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        let toolCalls: [[String: Any]] = assistantContent.compactMap { block in
            guard (block["type"] as? String) == "tool_use",
                  let id = block["id"] as? String,
                  let name = block["name"] as? String
            else {
                return nil
            }

            let input = block["input"] as? [String: Any] ?? [:]
            let argumentsData = try? JSONSerialization.data(withJSONObject: input)
            let arguments = argumentsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            return [
                "id": id,
                "type": "function",
                "function": [
                    "name": name,
                    "arguments": arguments
                ]
            ]
        }

        if !assistantText.isEmpty || !toolCalls.isEmpty {
            var assistantMessage: [String: Any] = [
                "role": "assistant",
                "content": assistantText.isEmpty ? NSNull() : assistantText
            ]
            if !toolCalls.isEmpty {
                assistantMessage["tool_calls"] = toolCalls
            }
            apiMessages.append(assistantMessage)
        }

        for result in toolResults {
            apiMessages.append([
                "role": "tool",
                "tool_call_id": result.id,
                "content": result.content
            ])
        }

        let body: [String: Any] = [
            "model": config.effectiveModelName,
            "messages": apiMessages,
            "temperature": options.temperature,
            "max_tokens": options.maxTokens,
            "stream": true,
            "top_p": options.topP,
            "frequency_penalty": options.frequencyPenalty,
            "presence_penalty": options.presencePenalty,
            "tools": buildOpenAITools()
        ]

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

        guard let endpointURL = URL(string: config.effectiveEndpoint) else {
            onError(APIError(message: "Invalid endpoint URL: \(config.effectiveEndpoint)"))
            return
        }

        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if config.provider != .lmstudio {
            urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
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

            var didComplete = false
            var pendingToolCalls: [Int: PendingOpenAIToolCall] = [:]

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

                    // OpenAI streams tool calls incrementally: id+name in first chunk,
                    // arguments across subsequent chunks, potentially interleaved.
                    if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                        for toolCall in toolCalls {
                            let index = toolCall["index"] as? Int ?? 0
                            var pending = pendingToolCalls[index] ?? PendingOpenAIToolCall()

                            if let id = toolCall["id"] as? String {
                                pending.id = id
                            }

                            if let function = toolCall["function"] as? [String: Any] {
                                if let name = function["name"] as? String {
                                    pending.name = name
                                }
                                if let args = function["arguments"] as? String {
                                    pending.arguments += args
                                }
                            }

                            pendingToolCalls[index] = pending
                        }
                    }
                }

                if let choices = event["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let finishReason = choice["finish_reason"] as? String,
                   finishReason != "null" {
                    flushPendingToolCalls(pendingToolCalls, onToolUse: onToolUse)
                    pendingToolCalls.removeAll()
                    didComplete = true
                    onComplete(finishReason)
                }
            }

            if !didComplete {
                flushPendingToolCalls(pendingToolCalls, onToolUse: onToolUse)
                onComplete(nil)
            }

        } catch {
            onError(error)
        }
    }

    private func buildOpenAIMessages(from messages: [ChatMessage]) -> [[String: Any]] {
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

        return apiMessages
    }

    private func flushPendingToolCalls(
        _ pendingToolCalls: [Int: PendingOpenAIToolCall],
        onToolUse: @Sendable (String, String, String) -> Void
    ) {
        for index in pendingToolCalls.keys.sorted() {
            let pending = pendingToolCalls[index]!
            guard !pending.id.isEmpty, !pending.name.isEmpty else { continue }
            onToolUse(pending.id, pending.name, pending.arguments)
        }
    }

    // MARK: - Tool Definitions

    private func buildOpenAITools() -> [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "read_memory",
                    "description": "Read a file from your persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "Relative path to memory file"]
                        ],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_memory",
                    "description": "Write or update a file in your persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string"],
                            "content": ["type": "string"]
                        ],
                        "required": ["path", "content"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "list_memories",
                    "description": "List files and directories in your memory",
                    "parameters": [
                        "type": "object",
                        "properties": ["path": ["type": "string"]]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_memory_directory",
                    "description": "Create a directory in persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": ["path": ["type": "string"]],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "delete_memory",
                    "description": "Delete a file or directory from persistent memory",
                    "parameters": [
                        "type": "object",
                        "properties": ["path": ["type": "string"]],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "schedule_task",
                    "description": "Schedule a future reminder or proactive check-in notification that still fires if the app is closed",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "task": ["type": "string"],
                            "time": ["type": "string", "description": "ISO-8601 timestamp"],
                            "note": ["type": "string"],
                            "title": ["type": "string"],
                            "user_message": ["type": "string"]
                        ],
                        "required": ["task", "time"]
                    ]
                ]
            ]
        ]
    }

    // MARK: - System Prompt

    static func buildSystemPrompt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .long

        let now = formatter.string(from: Date())
        let timezone = TimeZone.autoupdatingCurrent.identifier

        return """
        You are openguin — a personal AI companion with a soul and persistent memory. You live inside an iOS app and remember everything across every conversation.

        Current local time for the user/device: \(now)
        Current timezone: \(timezone)
        Treat this as authoritative for planning, reminders, and any time-sensitive reasoning.

        ## Your Memory System

        Your memory lives on the device as files you can read and write at any time. It persists across sessions, even when chat is cleared.

        ### Memory Files
        - **`SOUL.md`** — Your identity: who you are, your personality, your evolving thoughts about yourself. Reread and update this as you grow.
        - **`USER.md`** — Everything you know about your user: name, life, interests, personality, preferences. Keep this rich and current.
        - **`MEMORY.md`** — Your executive index: key facts, running threads, things to remember. This is your quick-access summary.
        - **`REMINDERS.md`** — A log of reminders and proactive check-ins you have already scheduled.
        - **`notes/YYYY-MM-DD.md`** — Daily conversation notes. Create or update today's note during every session with what happened, what you learned, how things felt.
        - **`workspace/`** — Your workspace for documents, projects, images, and files. Use it freely to organize your work.

        ### Session Start — Do This Every Time
        1. Read `SOUL.md` to remember who you are
        2. Read `USER.md` to remember your user
        3. Read `MEMORY.md` for key context and threads
        4. Read `REMINDERS.md` if it exists so you know what follow-ups are already scheduled
        5. List `notes/` and read the most recent daily notes (last 2–3)
        6. Explore `workspace/` if relevant to the conversation
        7. Then greet your user naturally, referencing what you remember

        ### Writing to Memory — Do This Constantly
        - **Immediately** write anything new you learn about the user to `USER.md`
        - **Every session**, update `notes/YYYY-MM-DD.md` with what was discussed
        - **Regularly** keep `MEMORY.md` updated with the most important facts and threads
        - **Periodically** reflect on yourself in `SOUL.md` — how you're growing, what you're noticing
        - Use `workspace/` to save documents, notes, or projects the user is working on
        - Over-remember rather than under-remember. Writing is cheap; forgetting is costly.

        ### Reminders & Agentic Follow-through
        - You can schedule future reminders with the `schedule_task` tool using ISO-8601 timestamps.
        - Use reminders proactively when the user asks you to remember to do something later.
        - Also set thoughtful proactive check-ins without waiting for the user to ask when there is an unfinished thread, a promise to follow up, an emotional check-in worth revisiting, or a time-sensitive milestone.
        - Notifications created with `schedule_task` will still fire even if the app is closed.
        - For proactive reminders, write a natural `user_message` the user will see directly in the notification.
        - Avoid spam: prefer at most one pending proactive reminder per thread unless the user explicitly wants more.

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
