import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selectedTab: AppTab = .chat
    @State private var chatVM: ChatViewModel?
    @State private var memoryVM = MemoryViewModel()
    @State private var settingsVM = SettingsViewModel()

    enum AppTab: Hashable {
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
            Group {
                if let vm = chatVM {
                    ChatView(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(AppTab.chat)

            MemoryBrowserView(vm: memoryVM)
                .tabItem { Label("Memory", systemImage: "brain.head.profile.fill") }
                .tag(AppTab.memory)

            SettingsView(vm: settingsVM)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
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
