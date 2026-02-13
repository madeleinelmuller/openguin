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

    private let apiService = ClaudeAPIService()
    private let memoryManager = MemoryManager.shared
    private var pendingToolCalls: [(id: String, name: String, input: [String: Any])] = []
    private var assistantContentBlocks: [[String: Any]] = []
    private var currentStreamText: String = ""
    private var conversationHistory: [ChatMessage] = []

    private var currentAPIKey: String {
        SettingsManager.shared.effectiveAPIKey
    }

    private var currentModel: String {
        SettingsManager.shared.selectedModel.rawValue
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
            content: "[System: You are starting a new conversation session. Begin by reading your memory files (about_me.md, about_user.md, and list memories/) to recall your context. Then greet the user warmly based on what you remember about them. If this is a first conversation, introduce yourself briefly.]"
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
        let apiKey = currentAPIKey
        let model = currentModel

        await apiService.streamMessage(
            apiKey: apiKey,
            model: model,
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
            onToolUse: { [weak self] id, name, input in
                Task { @MainActor in
                    guard let self else { return }
                    self.pendingToolCalls.append((id: id, name: name, input: input))
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
            assistantContentBlocks.append([
                "type": "tool_use",
                "id": tool.id,
                "name": tool.name,
                "input": tool.input
            ])

            let result = await memoryManager.executeTool(name: tool.name, input: tool.input)
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
        let apiKey = currentAPIKey
        let model = currentModel

        assistantContentBlocks = []

        await apiService.sendToolResults(
            apiKey: apiKey,
            model: model,
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
            onToolUse: { [weak self] id, name, input in
                Task { @MainActor in
                    guard let self else { return }
                    self.pendingToolCalls.append((id: id, name: name, input: input))
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
}
