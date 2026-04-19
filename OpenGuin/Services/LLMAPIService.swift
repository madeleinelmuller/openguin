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
                    let url = URL(string: config.endpoint + "/v1/messages")!
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
                        continuation.yield(.error(LLMError.httpError(statusCode)))
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
                    let url = URL(string: config.endpoint + "/v1/chat/completions")!
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
                        "stream": true
                    ]
                    if !toolBlocks.isEmpty {
                        body["tools"] = toolBlocks
                        body["tool_choice"] = "auto"
                    }

                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        continuation.yield(.error(LLMError.httpError(statusCode)))
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

enum LLMError: Error, LocalizedError {
    case httpError(Int)
    case noContent
    case invalidEndpoint

    var errorDescription: String? {
        switch self {
        case .httpError(let code): "API error \(code)"
        case .noContent: "No content returned"
        case .invalidEndpoint: "Invalid endpoint URL"
        }
    }
}
