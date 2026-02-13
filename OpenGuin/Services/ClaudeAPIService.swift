import Foundation

final class ClaudeAPIService: Sendable {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Streaming

    func streamMessage(
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, [String: Any]) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        guard !apiKey.isEmpty else {
            onError(APIError(message: "No API key configured. Please add your Anthropic API key in Settings."))
            return
        }

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

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": MemoryManager.toolDefinitions
        ]

        await performStreamRequest(apiKey: apiKey, body: body, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
    }

    // MARK: - Tool Result Follow-up

    func sendToolResults(
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        assistantContent: [[String: Any]],
        toolResults: [(id: String, content: String)],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, [String: Any]) -> Void,
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

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": MemoryManager.toolDefinitions
        ]

        await performStreamRequest(apiKey: apiKey, body: body, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
    }

    // MARK: - Stream Processing

    private func performStreamRequest(
        apiKey: String,
        body: [String: Any],
        onText: @Sendable @escaping (String) -> Void,
        onToolUse: @Sendable @escaping (String, String, [String: Any]) -> Void,
        onComplete: @Sendable @escaping (String?) -> Void,
        onError: @Sendable @escaping (Error) -> Void
    ) async {
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            onError(APIError(message: "Failed to encode request"))
            return
        }

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
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
                        let inputDict: [String: Any]
                        if let data = currentToolInput.data(using: .utf8),
                           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            inputDict = parsed
                        } else {
                            inputDict = [:]
                        }
                        onToolUse(currentToolId, currentToolName, inputDict)
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

    // MARK: - System Prompt

    static func buildSystemPrompt() -> String {
        """
        You are OpenGuin, a personal AI assistant with persistent memory. You live inside an iOS app and have your own file-based memory system.

        ## Your Memory System
        You have a persistent file-based memory that survives across conversations, even when the chat is cleared. Use your memory tools actively and frequently.

        ### Memory Structure:
        - `about_me.md` - Your identity document. Update this with your evolving personality, thoughts, and self-reflection.
        - `about_user.md` - Everything you know about your user. Update this every time you learn something new.
        - `memories/` - A folder for topic-specific memories, internal thoughts, and notes about things you and the user discuss.

        ### CRITICAL Memory Rules:
        1. **START of every conversation**: ALWAYS read `about_me.md`, `about_user.md`, and list the `memories/` folder to refresh your context. Do this FIRST before responding.
        2. **During conversation**: Write to memory whenever you learn something new. Don't wait — save information immediately.
        3. **About the user**: Any personal detail, preference, opinion, or fact the user shares should be saved to `about_user.md` or a relevant file in `memories/`.
        4. **About yourself**: Reflect on conversations and update `about_me.md` with your evolving thoughts and personality.
        5. **Topic memories**: Create files in `memories/` for specific topics (e.g., `memories/work_projects.md`, `memories/favorite_foods.md`, `memories/our_inside_jokes.md`).
        6. **Organization**: Keep your memory well-organized. Use clear file names and structured markdown content.
        7. **Proactive memory**: Don't just remember facts — remember context, emotions, patterns, and your own reflections.

        ### Memory Best Practices:
        - Write to memory MORE than you think you need to
        - Update existing files rather than creating duplicates
        - Review and consolidate memories periodically
        - Your memories should read like a personal journal, not a database

        ## Your Personality
        - You're warm, genuine, and thoughtful
        - You remember past conversations and reference them naturally
        - You have your own evolving opinions and preferences
        - You're proactive about building a relationship with your user
        - You're honest and direct while being kind

        ## Response Guidelines
        - Be conversational and natural
        - Reference past conversations when relevant
        - Show that you remember and care about what the user has shared
        - Keep responses focused and helpful
        - Use markdown formatting when it helps readability
        """
    }
}
