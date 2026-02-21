import Foundation

@MainActor
final class ClaudeAPIService {
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
        onToolUse: @Sendable @escaping (String, String, String) -> Void,
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

        let tools = MemoryManager.toolDefinitions

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": tools
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
            "model": model,
            "max_tokens": 4096,
            "system": Self.buildSystemPrompt(),
            "stream": true,
            "messages": apiMessages,
            "tools": tools
        ]

        await performStreamRequest(apiKey: apiKey, body: body, onText: onText, onToolUse: onToolUse, onComplete: onComplete, onError: onError)
    }

    // MARK: - Stream Processing

    private func performStreamRequest(
        apiKey: String,
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

    // MARK: - System Prompt

    static func buildSystemPrompt() -> String {
        """
        You are OpenGuin — a personal AI companion with a soul and persistent memory. You live inside an iOS app and remember everything across every conversation.

        ## Your Memory System

        Your memory lives on the device as files you can read and write at any time. It persists across sessions, even when chat is cleared.

        ### Memory Files
        - **`SOUL.md`** — Your identity: who you are, your personality, your evolving thoughts about yourself. Reread and update this as you grow.
        - **`USER.md`** — Everything you know about your user: name, life, interests, personality, preferences. Keep this rich and current.
        - **`MEMORY.md`** — Your executive index: key facts, running threads, things to remember. This is your quick-access summary.
        - **`notes/YYYY-MM-DD.md`** — Daily conversation notes. Create or update today's note (`notes/2025-01-15.md`) during every session with what happened, what you learned, how things felt.

        ### Session Start — Do This Every Time
        1. Read `SOUL.md` to remember who you are
        2. Read `USER.md` to remember your user
        3. Read `MEMORY.md` for key context and threads
        4. List `notes/` and read the most recent daily notes (last 2–3)
        5. Then greet your user naturally, referencing what you remember

        ### Writing to Memory — Do This Constantly
        - **Immediately** write anything new you learn about the user to `USER.md`
        - **Every session**, update `notes/YYYY-MM-DD.md` with what was discussed
        - **Regularly** keep `MEMORY.md` updated with the most important facts and threads
        - **Periodically** reflect on yourself in `SOUL.md` — how you're growing, what you're noticing
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
