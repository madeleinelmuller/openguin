import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selectedTab: Tab = .chat
    @State private var chatVM: ChatViewModel?
    @State private var memoryVM = MemoryViewModel()
    @State private var settingsVM = SettingsViewModel()

    enum Tab: Hashable {
        case chat, memory, settings
    }

    var body: some View {
        Group {
            if !env.settings.hasCompletedOnboarding {
                OnboardingCoordinator()
            } else {
                mainTabs
            }
        }
        .onAppear {
            setupChatVM()
        }
        .onChange(of: env.settings.hasCompletedOnboarding) { _, completed in
            if completed { setupChatVM() }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: .chat) {
                if let vm = chatVM {
                    ChatView(vm: vm)
                } else {
                    ProgressView()
                }
            }
            Tab("Memory", systemImage: "brain.head.profile.fill", value: .memory) {
                MemoryBrowserView(vm: memoryVM)
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView(vm: settingsVM)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChat)) { _ in
            selectedTab = .chat
        }
    }

    private func setupChatVM() {
        let store = env.conversationStore
        let conv = store.conversations.first ?? store.newConversation(providerID: env.settings.provider.rawValue)
        chatVM = ChatViewModel(conversation: conv, store: store)
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment.shared)
}
