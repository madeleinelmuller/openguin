import AppIntents
import Foundation

// MARK: - Open Chat

struct OpenOpenGuinIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Openguin"
    static let description = IntentDescription("Opens the Openguin chat.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .switchToChat, object: nil)
        return .result()
    }
}

// MARK: - Create Reminder via Shortcut

struct CreateReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Reminder"
    static let description = IntentDescription("Creates a reminder via Openguin.")

    @Parameter(title: "Title") var title: String
    @Parameter(title: "Due Date") var dueDate: Date?
    @Parameter(title: "Notes") var notes: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = await RemindersService.shared.createReminder(
            title: title,
            dueDate: dueDate.map { ISO8601DateFormatter().string(from: $0) },
            notes: notes,
            listName: nil
        )
        return .result(value: result)
    }
}

// MARK: - Create Calendar Event via Shortcut

struct CreateCalendarEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Calendar Event"
    static let description = IntentDescription("Creates a calendar event via Openguin.")

    @Parameter(title: "Title") var title: String
    @Parameter(title: "Start Date") var startDate: Date
    @Parameter(title: "End Date") var endDate: Date
    @Parameter(title: "Notes") var notes: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let formatter = ISO8601DateFormatter()
        let result = await CalendarService.shared.createEvent(
            title: title,
            start: formatter.string(from: startDate),
            end: formatter.string(from: endDate),
            notes: notes,
            calendarName: nil
        )
        return .result(value: result)
    }
}

// MARK: - App Shortcuts

struct OpenGuinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenOpenGuinIntent(),
            phrases: ["Open \(.applicationName)", "Chat with \(.applicationName)"],
            shortTitle: "Open Openguin",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: ["Remind me with \(.applicationName)", "Add a reminder in \(.applicationName)"],
            shortTitle: "Create Reminder",
            systemImageName: "bell.fill"
        )
        AppShortcut(
            intent: CreateCalendarEventIntent(),
            phrases: ["Add event with \(.applicationName)", "Create calendar event in \(.applicationName)"],
            shortTitle: "Create Event",
            systemImageName: "calendar.badge.plus"
        )
    }
}
