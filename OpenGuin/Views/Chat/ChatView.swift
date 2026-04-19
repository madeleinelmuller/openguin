import SwiftUI

struct ChatView: View {
    @State var vm: ChatViewModel
    @State private var showConversations = false
    @State private var showVoiceRecorder = false
    @State private var isRecording = false
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Messages
                MessageListView(
                    messages: vm.conversation.messages,
                    isStreaming: vm.isStreaming,
                    activeToolName: vm.activeToolName
                )
                .ignoresSafeArea(edges: .bottom)

                // Voice recorder overlay
                if showVoiceRecorder {
                    VoiceRecorderOverlay(
                        recording: env.recording,
                        onDone: { transcript in
                            showVoiceRecorder = false
                            if let text = transcript, !text.isEmpty {
                                vm.sendVoiceTranscript(text)
                            }
                        },
                        onCancel: {
                            env.recording.cancelRecording()
                            showVoiceRecorder = false
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }

                // Input bar
                if !showVoiceRecorder {
                    ChatInputBar(
                        text: $vm.inputText,
                        isStreaming: vm.isStreaming,
                        onSend: { vm.sendMessage() },
                        onMicTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showVoiceRecorder = true
                            }
                            Task { await env.recording.startRecording() }
                        },
                        onCancelStream: { vm.cancelStreaming() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(vm.conversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HapticButton(.light, action: { showConversations.toggle() }) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: { vm.clearConversation() }) {
                            Label("Clear conversation", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showConversations) {
                ConversationsView(
                    vm: ConversationsViewModel(store: env.conversationStore),
                    currentConversationID: vm.conversation.id,
                    onSelect: { conversation in
                        vm = ChatViewModel(conversation: conversation, store: env.conversationStore)
                        showConversations = false
                    },
                    onNew: {
                        let conv = env.conversationStore.newConversation(providerID: SettingsManager.shared.provider.rawValue)
                        vm = ChatViewModel(conversation: conv, store: env.conversationStore)
                        showConversations = false
                    }
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
}

// MARK: - Voice Recorder Overlay

struct VoiceRecorderOverlay: View {
    let recording: RecordingService
    let onDone: (String?) async -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            GlassCard(cornerRadius: 28, padding: 24) {
                VStack(spacing: 20) {
                    // Status
                    Group {
                        switch recording.state {
                        case .idle:
                            Label("Starting…", systemImage: "mic")
                                .foregroundStyle(.secondary)
                        case .recording:
                            Label("Recording", systemImage: "mic.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse)
                        case .transcribing:
                            Label("Transcribing…", systemImage: "waveform")
                                .foregroundStyle(.secondary)
                        case .done:
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed(let msg):
                            Label(msg, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .font(.headline)
                    .animation(.spring(response: 0.3), value: recording.state.description)

                    // Waveform
                    VoiceWaveformView(levels: recording.audioLevels)

                    // Buttons
                    HStack(spacing: 16) {
                        HapticButton(.medium, action: onCancel) {
                            Text("Cancel")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        HapticButton(.medium) {
                            Task {
                                let transcript = await recording.stopAndTranscribe()
                                await onDone(transcript)
                            }
                        } label: {
                            Text("Send")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled({
                            if case .recording = recording.state { return false }
                            return true
                        }())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.ultraThinMaterial.opacity(0.6))
        .ignoresSafeArea()
    }
}
