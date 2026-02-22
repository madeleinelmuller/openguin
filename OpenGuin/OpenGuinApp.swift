import SwiftUI

@main
struct OpenGuinApp: App {
    init() {
        // Register notification delegate before the app finishes launching
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request permission on first launch (system only shows dialog once)
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
