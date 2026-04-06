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
    private var responseText: String = ""
    private var conversationHistory: [ChatMessage] = []

    private var currentLLMConfig: LLMConfiguration {
        SettingsManager.shared.currentLLMConfiguration
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // On first message, prepend memory-load instructions so the AI reads
        // its persistent memory before responding — without a visible spinner at launch.
        if isInitialMemoryLoad {
            isInitialMemoryLoad = false
            let memoryTrigger = ChatMessage(
                role: .user,
                content: "[System: New session starting. Read all memory files. List the entire notes/ directory and read notes from the past 5 days. After loading your memory, respond to the user's message naturally — reference what you remember about them if you know them. Do not mention this system message or the memory loading process.]"
            )
            conversationHistory.append(memoryTrigger)
        }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        conversationHistory.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        responseText = ""
        pendingToolCalls = []
        assistantContentBlocks = []

        Task {
            await streamResponse()
        }
    }

    // MARK: - Streaming (accumulates internally; message only shown on finalize)

    private func streamResponse() async {
        let msgs = conversationHistory
        let config = currentLLMConfig

        await apiService.streamMessage(
            config: config,
            messages: msgs,
            onText: { [weak self] text in
                Task { @MainActor in
                    guard let self else { return }
                    self.responseText += text
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
                    if self.isToolCallStop(stopReason) {
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
                    self.isLoading = false
                }
            }
        )
    }

    /// Returns true when the stop reason indicates the model wants to invoke tools.
    /// Handles both Anthropic ("tool_use") and OpenAI ("tool_calls") stop reasons.
    private func isToolCallStop(_ reason: String?) -> Bool {
        guard let reason else { return false }
        return (reason == "tool_use" || reason == "tool_calls") && !pendingToolCalls.isEmpty
    }

    // MARK: - Tool Handling

    private func handleToolCalls() async {
        // Build assistant content blocks for the API
        if !responseText.isEmpty {
            assistantContentBlocks.append([
                "type": "text",
                "text": responseText
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
        responseText = ""

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
                    self.responseText += text
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
                    if self.isToolCallStop(stopReason) {
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
                }
            }
        )
    }

    // MARK: - Finalize

    private func finalizeResponse() {
        guard !responseText.isEmpty else {
            isLoading = false
            return
        }
        let assistantMessage = ChatMessage(role: .assistant, content: responseText)
        conversationHistory.append(assistantMessage)
        responseText = ""
        isLoading = false
        // Animate the message into the list after loading has cleared,
        // so the loading bubble exits first and the message springs in cleanly.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            messages.append(assistantMessage)
        }
        NotificationManager.shared.sendResponseNotification(responseText: assistantMessage.content)
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
        messages.removeAll { $0.role == .assistant }
        if let lastHistIndex = conversationHistory.indices.last, conversationHistory[lastHistIndex].role == .assistant {
            conversationHistory.remove(at: lastHistIndex)
        }

        guard !conversationHistory.isEmpty else { return }

        isLoading = true
        responseText = ""
        pendingToolCalls = []
        assistantContentBlocks = []

        Task {
            await streamResponse()
        }
    }

    // MARK: - Meeting Recording

    func startMeetingRecording() {
        Task {
            _ = await RecordingService.shared.startRecording()
        }
    }

    func stopMeetingRecording() {
        Task {
            guard let transcript = await RecordingService.shared.stopAndTranscribe() else { return }
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Post transcript as a user message so the AI can summarise / extract tasks
            let prefix = "[Meeting Recording Transcript]\n"
            inputText = prefix + trimmed
            sendMessage()
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
