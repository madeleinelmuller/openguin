import Foundation
import EventKit

actor RemindersService {
    static let shared = RemindersService()
    private let store = EKEventStore()
    private var authorized = false

    private init() {}

    func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            do {
                authorized = try await store.requestFullAccessToReminders()
            } catch {
                authorized = false
            }
        } else {
            authorized = await withCheckedContinuation { cont in
                store.requestAccess(to: .reminder) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
        return authorized
    }

    func createReminder(title: String, dueDate: String?, notes: String?, listName: String?) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Reminders access not granted. Please enable in Settings > Privacy > Reminders."
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes

        if let dueDateStr = dueDate, !dueDateStr.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFullDate, .withTime]
            if let date = formatter.date(from: dueDateStr) ?? parseFlex(dueDateStr) {
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                reminder.dueDateComponents = comps
                reminder.addAlarm(EKAlarm(absoluteDate: date))
            }
        }

        if let listName = listName, !listName.isEmpty {
            reminder.calendar = store.calendars(for: .reminder).first { $0.title == listName } ?? store.defaultCalendarForNewReminders()
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        do {
            try store.save(reminder, commit: true)
            var msg = "Created reminder: '\(title)'"
            if let due = reminder.dueDateComponents?.date {
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                msg += " (due \(df.string(from: due)))"
            }
            msg += ". ID: \(reminder.calendarItemIdentifier)"
            return msg
        } catch {
            return "Error creating reminder: \(error.localizedDescription)"
        }
    }

    func listReminders(listName: String?) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Reminders access not granted."
        }

        var calendars = store.calendars(for: .reminder)
        if let listName = listName, !listName.isEmpty {
            calendars = calendars.filter { $0.title == listName }
        }

        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars.isEmpty ? nil : calendars)

        return await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders, !reminders.isEmpty else {
                    cont.resume(returning: "No incomplete reminders found.")
                    return
                }

                let df = DateFormatter()
                df.dateStyle = .short
                df.timeStyle = .short

                let lines = reminders.prefix(50).map { r -> String in
                    var line = "- \(r.title ?? "Untitled")"
                    if let comps = r.dueDateComponents, let date = comps.date {
                        line += " (due \(df.string(from: date)))"
                    }
                    line += " | ID: \(r.calendarItemIdentifier)"
                    return line
                }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }

    func completeReminder(reminderID: String) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Reminders access not granted."
        }

        guard let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return "Error: Reminder not found with ID \(reminderID)."
        }

        item.isCompleted = true
        do {
            try store.save(item, commit: true)
            return "Completed reminder: '\(item.title ?? "Untitled")'"
        } catch {
            return "Error completing reminder: \(error.localizedDescription)"
        }
    }

    func deleteReminder(reminderID: String) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Reminders access not granted."
        }

        guard let item = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            return "Error: Reminder not found with ID \(reminderID)."
        }

        do {
            try store.remove(item, commit: true)
            return "Deleted reminder: '\(item.title ?? "Untitled")'"
        } catch {
            return "Error deleting reminder: \(error.localizedDescription)"
        }
    }

    private func ensureAuthorized() async -> Bool {
        if authorized { return true }
        return await requestAccess()
    }

    private func parseFlex(_ str: String) -> Date? {
        let formatters = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formatters {
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }
        return nil
    }
}

extension DateComponents {
    var date: Date? {
        Calendar.current.date(from: self)
    }
}
