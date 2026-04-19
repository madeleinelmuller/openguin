import SwiftUI

@main
struct OpenGuinApp: App {
    init() {
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
