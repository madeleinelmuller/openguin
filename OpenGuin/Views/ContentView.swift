import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .chat
    @Namespace private var tabNamespace

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: "message.fill", value: .chat) {
                ChatView()
            }

            Tab("Memory", systemImage: "brain.head.profile.fill", value: .memory) {
                MemoryBrowserView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.automatic)
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
