import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    // MARK: - Send Notification

    /// Sends a local notification only when the app is not in the foreground.
    func sendResponseNotification(responseText: String) {
        // Must run on main thread to check applicationState
        Task { @MainActor in
            guard UIApplication.shared.applicationState != .active else { return }

            let content = UNMutableNotificationContent()
            content.title = "openguin"
            let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = trimmed.isEmpty ? "New message" : String(trimmed.prefix(160))
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // deliver immediately
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress banner when app is foregrounded
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // User tapped the notification — just complete (app opens to chat)
        completionHandler()
    }
}
