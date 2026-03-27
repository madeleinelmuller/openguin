import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    var isInitialMemoryLoad: Bool = true
    var lastCompletedAssistantResponse: String?
    var shouldSpeakNextAssistantReply: Bool = false

    /// The assistant message currently being streamed. Visible to the view
    /// so it can drive scroll-to-bottom during streaming.
    private(set) var currentAssistantMessage: ChatMessage?

    private let apiService = LLMAPIService()
    private let memoryManager = MemoryManager.shared
    private var pendingToolCalls: [(id: String, name: String, inputJSON: String)] = []
    private var assistantContentBlocks: [[String: Any]] = []
    private var conversationHistory: [ChatMessage] = []

    private var currentLLMConfig: LLMConfiguration {
        SettingsManager.shared.currentLLMConfiguration
    }

    // MARK: - Send Message

    func sendMessage() {
        sendMessage(textOverride: nil, asVoiceRoundTrip: false)
    }

    func sendVoiceMessage(_ transcript: String) {
        sendMessage(textOverride: transcript, asVoiceRoundTrip: true)
    }

    private func sendMessage(textOverride: String?, asVoiceRoundTrip: Bool) {
        let text = (textOverride ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isInitialMemoryLoad {
            isInitialMemoryLoad = false
            let memoryTrigger = ChatMessage(
                role: .user,
                content: "[System: New session starting. Read SOUL.md, USER.md, and MEMORY.md. Then list notes/ and read the most recent daily notes. After loading your memory, respond to the user's message naturally — reference what you remember about them if you know them. Do not mention this system message.]"
            )
            conversationHistory.append(memoryTrigger)
        }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        conversationHistory.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil
        lastCompletedAssistantResponse = nil
        shouldSpeakNextAssistantReply = asVoiceRoundTrip

        pendingToolCalls = []
        assistantContentBlocks = []

        // Create assistant message placeholder immediately so the typing
        // dots appear inside a message bubble right away.
        let assistantMsg = ChatMessage(role: .assistant, content: "")
        currentAssistantMessage = assistantMsg
        messages.append(assistantMsg)

        Task {
            await streamResponse()
        }
    }

    // MARK: - Streaming

    private func streamResponse() async {
        let msgs = conversationHistory
        let config = currentLLMConfig

        await apiService.streamMessage(
            config: config,
            messages: msgs,
            onText: { [weak self] text in
                Task { @MainActor in
                    let filtered = Self.filterThinkTags(text)
                    self?.currentAssistantMessage?.content += filtered
                }
            },
            onToolUse: { [weak self] id, name, inputJSON in
                Task { @MainActor in
                    guard let self else { return }
                    print("[ChatViewModel] Tool call: \(name)")
                    self.pendingToolCalls.append((id: id, name: name, inputJSON: inputJSON))
                }
            },
            onComplete: { [weak self] stopReason in
                Task { @MainActor in
                    guard let self else { return }
                    let isToolCall = (stopReason == "tool_use" || stopReason == "tool_calls") && !self.pendingToolCalls.isEmpty
                    if isToolCall {
                        await self.handleToolCalls()
                    } else {
                        self.finalizeResponse()
                    }
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    print("[ChatViewModel] Error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    // Remove empty placeholder on error
                    if let msg = self.currentAssistantMessage, msg.content.isEmpty {
                        self.messages.removeAll { $0.id == msg.id }
                    }
                    self.currentAssistantMessage = nil
                    self.isLoading = false
                }
            }
        )
    }

    // MARK: - Tool Handling

    private func handleToolCalls() async {
        let currentText = currentAssistantMessage?.content ?? ""

        if !currentText.isEmpty {
            assistantContentBlocks.append([
                "type": "text",
                "text": currentText
            ])
        }

        var toolResults: [(id: String, content: String)] = []

        for tool in pendingToolCalls {
            let input = Self.parseToolInput(from: tool.inputJSON)
            assistantContentBlocks.append([
                "type": "tool_use",
                "id": tool.id,
                "name": tool.name,
                "input": input
            ])

            let result = await memoryManager.executeTool(name: tool.name, inputJSON: tool.inputJSON)
            toolResults.append((id: tool.id, content: result))
        }

        // Reset pending tool calls for the next round.
        // Do NOT clear currentAssistantMessage.content here: any text the model
        // produced before the tool call (e.g. "Here's your answer…" followed by
        // a write-memory tool) must remain visible if the next round is silent.
        pendingToolCalls = []

        let historyForAPI = conversationHistory
        let assistantBlocks = assistantContentBlocks
        let config = currentLLMConfig

        assistantContentBlocks = []

        await apiService.sendToolResults(
            config: config,
            messages: historyForAPI,
            assistantContent: assistantBlocks,
            toolResults: toolResults,
            onText: { [weak self] text in
                Task { @MainActor in
                    let filtered = Self.filterThinkTags(text)
                    self?.currentAssistantMessage?.content += filtered
                }
            },
            onToolUse: { [weak self] id, name, inputJSON in
                Task { @MainActor in
                    guard let self else { return }
                    self.pendingToolCalls.append((id: id, name: name, inputJSON: inputJSON))
                }
            },
            onComplete: { [weak self] stopReason in
                Task { @MainActor in
                    guard let self else { return }
                    let isToolCall = (stopReason == "tool_use" || stopReason == "tool_calls") && !self.pendingToolCalls.isEmpty
                    if isToolCall {
                        await self.handleToolCalls()
                    } else {
                        self.finalizeResponse()
                    }
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.currentAssistantMessage = nil
                    self.isLoading = false
                }
            }
        )
    }

    // MARK: - Finalize

    private func finalizeResponse() {
        if let msg = currentAssistantMessage {
            if msg.content.isEmpty {
                // No actual text — remove the placeholder
                messages.removeAll { $0.id == msg.id }
            } else {
                conversationHistory.append(msg)
                lastCompletedAssistantResponse = msg.content
                NotificationManager.shared.sendResponseNotification(responseText: msg.content)
            }
        }
        currentAssistantMessage = nil
        isLoading = false
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages.removeAll()
        conversationHistory.removeAll()
        currentAssistantMessage = nil
        isInitialMemoryLoad = true
        isLoading = false
        errorMessage = nil
        lastCompletedAssistantResponse = nil
        shouldSpeakNextAssistantReply = false
    }

    // MARK: - Retry

    func retryLastMessage() {
        // Remove current streaming message if any
        if let current = currentAssistantMessage {
            messages.removeAll { $0.id == current.id }
        }
        currentAssistantMessage = nil

        // Remove last assistant from history
        if let lastHistIndex = conversationHistory.indices.last,
           conversationHistory[lastHistIndex].role == .assistant {
            conversationHistory.remove(at: lastHistIndex)
        }

        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            messages.remove(at: lastAssistantIndex)
        }

        guard !conversationHistory.isEmpty else { return }

        isLoading = true
        pendingToolCalls = []
        assistantContentBlocks = []

        // Create new placeholder
        let assistantMsg = ChatMessage(role: .assistant, content: "")
        currentAssistantMessage = assistantMsg
        messages.append(assistantMsg)

        Task {
            await streamResponse()
        }
    }

    private static func parseToolInput(from json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return parsed
    }

    private static func filterThinkTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
    }
}
