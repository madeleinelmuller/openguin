import SwiftUI

@main
struct OpenGuinApp: App {
    @State private var env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(env)
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
