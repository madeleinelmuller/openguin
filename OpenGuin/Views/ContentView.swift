import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .chat

    var body: some View {
        contentTabs
            .onReceive(NotificationCenter.default.publisher(for: .openChatFromNotification)) { _ in
                withAnimation(.smooth) {
                    selectedTab = .chat
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openTasksTab)) { _ in
                withAnimation(.smooth) {
                    selectedTab = .tasks
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToSettings)) { _ in
                withAnimation(.smooth) {
                    selectedTab = .settings
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
    }

    private var contentTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: "message", value: .chat) {
                ChatView()
            }

            Tab("Tasks", systemImage: "checklist", value: .tasks) {
                TasksView()
            }

            Tab("Memory", systemImage: "brain.head.profile", value: .memory) {
                MemoryBrowserView()
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                ProviderSettingsView()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "openguin" else { return }
        switch url.host {
        case "tasks":
            withAnimation(.smooth) { selectedTab = .tasks }
        case "chat":
            withAnimation(.smooth) { selectedTab = .chat }
        default:
            break
        }
    }
}

enum AppTab: String, Hashable {
    case chat
    case tasks
    case memory
    case settings
}

#Preview {
    ContentView()
}
