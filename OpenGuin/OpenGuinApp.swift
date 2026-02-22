import SwiftUI
import UserNotifications

@main
struct OpenGuinApp: App {
    init() {
        Task {
            await NotificationManager.shared.requestPermission()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
