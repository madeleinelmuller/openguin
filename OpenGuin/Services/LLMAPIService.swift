import Foundation

enum StreamEvent: Sendable {
    case text(String)
    case toolUse(id: String, name: String, inputJSON: String)
    case complete(stopReason: String?)
    case error(Error)
}

struct LLMConfig: Sendable {
    let provider: LLMProvider
    let model: String
    let apiKey: String
    let endpoint: String
    let maxTokens: Int
    let systemPrompt: String
}

actor LLMAPIService {
    static let shared = LLMAPIService()
    private init() {}

    func stream(config: LLMConfig, messages: [ChatMessage], tools: [AgentTool]) -> AsyncStream<StreamEvent> {
        if config.provider == .anthropic {
            return streamAnthropic(config: config, messages: messages, tools: tools)
        } else {
            return streamOpenAICompat(config: config, messages: messages, tools: tools)
        }
    }

    // MARK: - Anthropic

    private func streamAnthropic(config: LLMConfig, messages: [ChatMessage], tools: [AgentTool]) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    let base = config.provider.normalizedEndpoint(from: config.endpoint)
                    guard let url = URL(string: base + config.provider.chatPath) else {
                        continuation.yield(.error(LLMError.invalidEndpoint))
                        continuation.finish()
                        return
                    }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    req.setValue("true", forHTTPHeaderField: "anthropic-beta")
                    req.timeoutInterval = 120

                    let apiMessages = messages.filter { $0.role != .system }.map { msg -> [String: Any] in
                        switch msg.role {
                        case .user:
                            return ["role": "user", "content": msg.content]
                        case .assistant:
                            return ["role": "assistant", "content": msg.content]
                        case .toolResult:
                            return [
                                "role": "user",
                                "content": [[
                                    "type": "tool_result",
                                    "tool_use_id": msg.toolCallID ?? "",
                                    "content": msg.content
                                ]]
                            ]
                        case .system:
                            return [:]
                        }
                    }.filter { !$0.isEmpty }

                    let toolBlocks = tools.map { $0.anthropicBlock() }

                    var body: [String: Any] = [
                        "model": config.model,
                        "max_tokens": config.maxTokens,
                        "stream": true,
                        "system": config.systemPrompt,
                        "messages": apiMessages
                    ]
                    if !toolBlocks.isEmpty {
                        body["tools"] = toolBlocks
                    }

                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        // Drain the body so we can surface a useful message
                        var bodyBytes: [UInt8] = []
                        bodyBytes.reserveCapacity(2048)
                        for try await byte in bytes {
                            bodyBytes.append(byte)
                            if bodyBytes.count >= 2048 { break }
                        }
                        let body = String(bytes: bodyBytes, encoding: .utf8) ?? ""
                        continuation.yield(.error(LLMError.httpErrorWithBody(statusCode, body, config.provider)))
                        continuation.finish()
                        return
                    }

                    var currentToolID = ""
                    var currentToolName = ""
                    var currentToolInput = ""
                    var stopReason: String? = nil

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]",
                              let data = jsonStr.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        let type = obj["type"] as? String ?? ""

                        switch type {
                        case "content_block_start":
                            if let block = obj["content_block"] as? [String: Any],
                               block["type"] as? String == "tool_use" {
                                currentToolID = block["id"] as? String ?? ""
                                currentToolName = block["name"] as? String ?? ""
                                currentToolInput = ""
                            }

                        case "content_block_delta":
                            if let delta = obj["delta"] as? [String: Any] {
                                let deltaType = delta["type"] as? String ?? ""
                                if deltaType == "text_delta", let text = delta["text"] as? String {
                                    continuation.yield(.text(text))
                                } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                                    currentToolInput += partial
                                }
                            }

                        case "message_delta":
                            if let delta = obj["delta"] as? [String: Any] {
                                stopReason = delta["stop_reason"] as? String
                            }

                        case "content_block_stop":
                            if !currentToolName.isEmpty {
                                continuation.yield(.toolUse(id: currentToolID, name: currentToolName, inputJSON: currentToolInput))
                                currentToolID = ""
                                currentToolName = ""
                                currentToolInput = ""
                            }

                        case "message_stop":
                            continuation.yield(.complete(stopReason: stopReason))
                            continuation.finish()
                            return

                        default:
                            break
                        }
                    }

                    continuation.yield(.complete(stopReason: stopReason))
                    continuation.finish()

                } catch {
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - OpenAI-compatible (OpenAI, Ollama, LM Studio)

    private func streamOpenAICompat(config: LLMConfig, messages: [ChatMessage], tools: [AgentTool]) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            Task {
                do {
                    let baseEndpoint = config.provider.normalizedEndpoint(from: config.endpoint)
                    guard let url = URL(string: baseEndpoint + config.provider.chatPath) else {
                        continuation.yield(.error(LLMError.invalidEndpoint))
                        continuation.finish()
                        return
                    }
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !config.apiKey.isEmpty {
                        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    req.timeoutInterval = 120

                    var apiMessages: [[String: Any]] = [
                        ["role": "system", "content": config.systemPrompt]
                    ]

                    for msg in messages where msg.role != .system {
                        switch msg.role {
                        case .user:
                            apiMessages.append(["role": "user", "content": msg.content])
                        case .assistant:
                            if let toolName = msg.toolName, !toolName.isEmpty {
                                apiMessages.append([
                                    "role": "assistant",
                                    "tool_calls": [[
                                        "id": msg.toolCallID ?? "",
                                        "type": "function",
                                        "function": ["name": toolName, "arguments": msg.content]
                                    ]]
                                ])
                            } else {
                                apiMessages.append(["role": "assistant", "content": msg.content])
                            }
                        case .toolResult:
                            apiMessages.append([
                                "role": "tool",
                                "tool_call_id": msg.toolCallID ?? "",
                                "content": msg.content
                            ])
                        case .system:
                            break
                        }
                    }

                    let toolBlocks = tools.map { $0.openAIBlock() }

                    var body: [String: Any] = [
                        "model": config.model,
                        "messages": apiMessages,
                        "stream": true,
                        "max_tokens": config.maxTokens
                    ]
                    if !toolBlocks.isEmpty {
                        body["tools"] = toolBlocks
                        body["tool_choice"] = "auto"
                    }

                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        // Drain the body so we can surface a useful message
                        var bodyBytes: [UInt8] = []
                        bodyBytes.reserveCapacity(2048)
                        for try await byte in bytes {
                            bodyBytes.append(byte)
                            if bodyBytes.count >= 2048 { break }
                        }
                        let body = String(bytes: bodyBytes, encoding: .utf8) ?? ""
                        continuation.yield(.error(LLMError.httpErrorWithBody(statusCode, body, config.provider)))
                        continuation.finish()
                        return
                    }

                    // Accumulate tool calls by index
                    var toolCallsAccum: [Int: (id: String, name: String, args: String)] = [:]
                    var stopReason: String? = nil

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]",
                              let data = jsonStr.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let choice = choices.first
                        else { continue }

                        if let reason = choice["finish_reason"] as? String, !reason.isEmpty, reason != "null" {
                            stopReason = reason
                        }

                        guard let delta = choice["delta"] as? [String: Any] else { continue }

                        if let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(.text(content))
                        }

                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for tc in toolCalls {
                                let idx = tc["index"] as? Int ?? 0
                                if toolCallsAccum[idx] == nil {
                                    let id = tc["id"] as? String ?? ""
                                    let funcObj = tc["function"] as? [String: Any]
                                    let name = funcObj?["name"] as? String ?? ""
                                    toolCallsAccum[idx] = (id: id, name: name, args: "")
                                }
                                if let funcObj = tc["function"] as? [String: Any],
                                   let argsChunk = funcObj["arguments"] as? String {
                                    toolCallsAccum[idx]?.args += argsChunk
                                }
                            }
                        }
                    }

                    for (_, tc) in toolCallsAccum.sorted(by: { $0.key < $1.key }) {
                        continuation.yield(.toolUse(id: tc.id, name: tc.name, inputJSON: tc.args))
                    }

                    continuation.yield(.complete(stopReason: stopReason))
                    continuation.finish()

                } catch {
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }
}

private extension String {
    func trimmingSuffix(_ suffix: Character) -> String {
        var result = self
        while result.last == suffix { result.removeLast() }
        return result
    }
}

enum LLMError: Error, LocalizedError {
    case httpError(Int)
    case httpErrorWithBody(Int, String, LLMProvider)
    case noContent
    case invalidEndpoint
    case missingAPIKey(LLMProvider)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "API error \(code)"
        case .httpErrorWithBody(let code, let body, let provider):
            return Self.describe(statusCode: code, body: body, provider: provider)
        case .noContent:
            return "No content returned"
        case .invalidEndpoint:
            return "Invalid endpoint URL"
        case .missingAPIKey(let provider):
            return "\(provider.displayName) API key is missing. Add it in Settings."
        }
    }

    private static func describe(statusCode: Int, body: String, provider: LLMProvider) -> String {
        // Try to pull a useful message out of common error shapes.
        var detail: String? = nil
        if let data = body.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = obj["error"] as? [String: Any] {
                detail = err["message"] as? String
            } else if let msg = obj["message"] as? String {
                detail = msg
            } else if let err = obj["error"] as? String {
                detail = err
            }
        }
        if detail == nil, !body.isEmpty {
            detail = String(body.prefix(240))
        }

        switch statusCode {
        case 401, 403:
            let hint = provider.requiresAPIKey
                ? "Check your \(provider.displayName) API key in Settings."
                : "Authorization failed."
            return detail.map { "\(hint)\n\n\($0)" } ?? hint
        case 404:
            let hint = "Endpoint not found — is \(provider.displayName) running at this URL? Verify the endpoint in Settings."
            return detail.map { "\(hint)\n\n\($0)" } ?? hint
        case 429:
            return detail.map { "Rate limited. \($0)" } ?? "Rate limited by \(provider.displayName)."
        case 500...599:
            return detail.map { "\(provider.displayName) server error (\(statusCode)). \($0)" } ?? "\(provider.displayName) server error (\(statusCode))."
        default:
            return detail.map { "\(provider.displayName) error \(statusCode): \($0)" } ?? "\(provider.displayName) error \(statusCode)"
        }
    }
}
