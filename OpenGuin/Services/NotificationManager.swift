import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
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
            content.userInfo = ["route": "chat"]

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // deliver immediately
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Schedules a local notification for a future time.
    func scheduleAgentTaskNotification(
        task: String,
        note: String?,
        title: String?,
        userMessage: String?,
        at date: Date
    ) async -> String {
        guard date > Date() else {
            return "[Error: Scheduled time must be in the future.]"
        }

        let content = UNMutableNotificationContent()
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserMessage = userMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        content.title = (trimmedTitle?.isEmpty == false ? trimmedTitle : "openguin") ?? "openguin"
        if let trimmedUserMessage, !trimmedUserMessage.isEmpty {
            content.body = trimmedUserMessage
        } else if let trimmedNote, !trimmedNote.isEmpty {
            content.body = "\(task) — \(trimmedNote)"
        } else {
            content.body = task
        }
        content.sound = .default
        content.userInfo = [
            "route": "chat",
            "task": task
        ]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let identifier = "scheduled-task-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Scheduled reminder '\(task)' for \(formatter.string(from: date)) (id: \(identifier)). It will fire even if the app is closed."
        } catch {
            return "[Error: Failed to schedule task notification: \(error.localizedDescription)]"
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
        NotificationCenter.default.post(name: .openChatFromNotification, object: response.notification.request.content.userInfo)
        completionHandler()
    }
}
