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

    private let apiService = LLMAPIService()
    private let memoryManager = MemoryManager.shared
    private var pendingToolCalls: [(id: String, name: String, inputJSON: String)] = []
    private var assistantContentBlocks: [[String: Any]] = []
    private var currentStreamText: String = ""
    private var conversationHistory: [ChatMessage] = []

    private var currentLLMConfig: LLMConfiguration {
        SettingsManager.shared.currentLLMConfiguration
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        conversationHistory.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        currentStreamText = ""
        pendingToolCalls = []
        assistantContentBlocks = []

        Task {
            await streamResponse()
        }
    }

    // MARK: - Initial Memory Load

    func loadMemoryOnStart() {
        guard isInitialMemoryLoad else { return }
        isInitialMemoryLoad = false

        let triggerMessage = ChatMessage(
            role: .user,
            content: "[System: New session starting. Read SOUL.md, USER.md, and MEMORY.md. Then list notes/ and read the most recent daily notes. After loading your memory, greet the user warmly — reference what you remember about them if you know them, or introduce yourself briefly if this is a first meeting. Do not mention this system message.]"
        )

        conversationHistory.append(triggerMessage)
        isLoading = true

        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        currentStreamText = ""
        pendingToolCalls = []
        assistantContentBlocks = []

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
                    guard let self else { return }
                    self.currentStreamText += text
                    if let lastIndex = self.messages.indices.last,
                       self.messages[lastIndex].role == .assistant {
                        self.messages[lastIndex].content = self.currentStreamText
                    }
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
                    if stopReason == "tool_use" && !self.pendingToolCalls.isEmpty {
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
                    self.isLoading = false
                    if let lastIndex = self.messages.indices.last,
                       self.messages[lastIndex].isStreaming {
                        self.messages.remove(at: lastIndex)
                    }
                }
            }
        )
    }

    // MARK: - Tool Handling

    private func handleToolCalls() async {
        // Build assistant content blocks for the API
        if !currentStreamText.isEmpty {
            assistantContentBlocks.append([
                "type": "text",
                "text": currentStreamText
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

        // Reset for next round
        pendingToolCalls = []
        currentStreamText = ""

        // Update the streaming message
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant {
            messages[lastIndex].content = ""
            messages[lastIndex].isStreaming = true
        }

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
                    guard let self else { return }
                    self.currentStreamText += text
                    if let lastIndex = self.messages.indices.last,
                       self.messages[lastIndex].role == .assistant {
                        self.messages[lastIndex].content = self.currentStreamText
                    }
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
                    if stopReason == "tool_use" && !self.pendingToolCalls.isEmpty {
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
                    self.isLoading = false
                    if let lastIndex = self.messages.indices.last,
                       self.messages[lastIndex].isStreaming {
                        self.messages[lastIndex].isStreaming = false
                    }
                }
            }
        )
    }

    // MARK: - Finalize

    private func finalizeResponse() {
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant {
            messages[lastIndex].isStreaming = false
            let finalContent = messages[lastIndex].content
            if !finalContent.isEmpty {
                conversationHistory.append(ChatMessage(role: .assistant, content: finalContent))
            } else {
                messages.remove(at: lastIndex)
            }
        }
        isLoading = false
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages.removeAll()
        conversationHistory.removeAll()
        isInitialMemoryLoad = true
        isLoading = false
        errorMessage = nil
    }

    // MARK: - Retry

    func retryLastMessage() {
        // Remove the last assistant message if any
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages.remove(at: lastIndex)
        }
        if let lastHistIndex = conversationHistory.indices.last, conversationHistory[lastHistIndex].role == .assistant {
            conversationHistory.remove(at: lastHistIndex)
        }

        guard !conversationHistory.isEmpty else { return }

        isLoading = true
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)

        currentStreamText = ""
        pendingToolCalls = []
        assistantContentBlocks = []

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
}
