import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    var conversation: Conversation
    var inputText: String = ""
    var isStreaming: Bool = false
    var activeToolName: String? = nil
    var error: String? = nil

    private let store: ConversationStore
    private let api = LLMAPIService.shared
    private let dispatcher = ToolDispatcher.shared
    private let settings = SettingsManager.shared
    private var streamTask: Task<Void, Never>?

    init(conversation: Conversation, store: ConversationStore) {
        self.conversation = conversation
        self.store = store
    }

    // MARK: - Send

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        // Preflight: surface missing credentials before hitting the wire.
        if let configError = preflightConfigError() {
            error = configError
            return
        }

        inputText = ""
        error = nil

        let userMsg = ChatMessage(role: .user, content: text)
        conversation.messages.append(userMsg)

        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(text.prefix(50))
        }

        store.update(conversation)
        startAgentLoop()
    }

    func sendVoiceTranscript(_ transcript: String) {
        inputText = "[Voice Recording Transcript]\n\n\(transcript)"
        sendMessage()
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        activeToolName = nil
    }

    func clearConversation() {
        cancelStreaming()
        conversation.messages.removeAll()
        store.update(conversation)
    }

    // MARK: - Agent Loop

    private func startAgentLoop() {
        isStreaming = true
        streamTask = Task {
            await runAgentLoop()
            isStreaming = false
            activeToolName = nil
        }
    }

    private func runAgentLoop() async {
        let config = buildConfig()
        var iterationCount = 0
        let maxIterations = 20

        while iterationCount < maxIterations {
            iterationCount += 1
            guard !Task.isCancelled else { return }

            let stream = await api.stream(
                config: config,
                messages: conversation.messages,
                tools: AgentTool.allTools
            )

            var accumulatedText = ""
            var pendingTools: [ToolCall] = []
            var stopReason: String? = nil
            var gotError = false

            for await event in stream {
                guard !Task.isCancelled else { return }

                switch event {
                case .text(let chunk):
                    accumulatedText += chunk

                case .toolUse(let id, let name, let inputJSON):
                    if let toolName = AgentToolName(rawValue: name) {
                        pendingTools.append(ToolCall(id: id, name: toolName, inputJSON: inputJSON))
                    }

                case .complete(let reason):
                    stopReason = reason

                case .error(let err):
                    error = err.localizedDescription
                    gotError = true
                }
            }

            if gotError { return }

            let isToolCall = stopReason == "tool_use" || stopReason == "tool_calls"

            if isToolCall && !pendingTools.isEmpty {
                // Append assistant message with tool intent (not shown in UI)
                if !accumulatedText.isEmpty {
                    let assistantMsg = ChatMessage(role: .assistant, content: accumulatedText)
                    conversation.messages.append(assistantMsg)
                    store.update(conversation)
                }

                // Execute each tool
                for tool in pendingTools {
                    guard !Task.isCancelled else { return }
                    activeToolName = tool.name.rawValue
                    let result = await dispatcher.execute(name: tool.name, inputJSON: tool.inputJSON)

                    let toolResult = ChatMessage(
                        role: .toolResult,
                        content: result,
                        toolCallID: tool.id,
                        toolName: tool.name.rawValue,
                        isRevealed: true
                    )
                    conversation.messages.append(toolResult)
                }
                activeToolName = nil

                // Continue loop to get next model response
                continue

            } else {
                // Final response
                if !accumulatedText.isEmpty {
                    finalizeMessage(accumulatedText)
                }
                return
            }
        }

        error = "Agent reached maximum iterations without completing."
    }

    private func finalizeMessage(_ text: String) {
        let msg = ChatMessage(role: .assistant, content: text, isRevealed: false)
        conversation.messages.append(msg)
        store.update(conversation)

        // Flip isRevealed after a short delay so WordRevealModifier's
        // animation(_:value:) picks up the transition. Animation itself
        // lives in the view layer (MessageRevealModifier).
        let msgID = msg.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            guard let idx = conversation.messages.firstIndex(where: { $0.id == msgID }) else { return }
            conversation.messages[idx].isRevealed = true
            store.update(conversation)
        }
    }

    private func preflightConfigError() -> String? {
        let provider = settings.provider
        let model = settings.activeModel(for: provider)
        if model.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No model selected for \(provider.displayName). Pick one in Settings."
        }
        if provider.requiresAPIKey {
            let key = settings.apiKey(for: provider).trimmingCharacters(in: .whitespaces)
            if key.isEmpty {
                return "\(provider.displayName) API key is missing. Add it in Settings."
            }
        } else {
            let raw = settings.endpoint(for: provider)
            let normalized = provider.normalizedEndpoint(from: raw)
            if URL(string: normalized) == nil {
                return "\(provider.displayName) endpoint is invalid. Check Settings."
            }
        }
        return nil
    }

    private func buildConfig() -> LLMConfig {
        let provider = settings.provider
        return LLMConfig(
            provider: provider,
            model: settings.activeModel(for: provider),
            apiKey: settings.apiKey(for: provider),
            endpoint: settings.endpoint(for: provider),
            maxTokens: settings.maxTokens,
            systemPrompt: SystemPromptBuilder.build(userName: settings.userName)
        )
    }
}
