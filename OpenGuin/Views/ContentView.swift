import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .chat

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: "message", value: .chat) {
                ChatView()
            }

            Tab("Memory", systemImage: "brain.head.profile", value: .memory) {
                MemoryBrowserView()
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                ProviderSettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onReceive(NotificationCenter.default.publisher(for: .switchToSettings)) { _ in
            withAnimation(.smooth) {
                selectedTab = .settings
            }
        }
    }
}

enum AppTab: String, Hashable {
    case chat
    case memory
    case settings
}

#Preview {
    ContentView()
}
