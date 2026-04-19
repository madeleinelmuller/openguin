import Foundation
import EventKit

actor CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private var authorized = false

    private init() {}

    func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            do {
                authorized = try await store.requestFullAccessToEvents()
            } catch {
                authorized = false
            }
        } else {
            authorized = await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
        return authorized
    }

    func createEvent(title: String, start: String, end: String, notes: String?, calendarName: String?) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Calendar access not granted. Please enable it in Settings > Privacy > Calendars."
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFullDate, .withTime]

        guard let startDate = formatter.date(from: start) ?? parseFlex(start),
              let endDate = formatter.date(from: end) ?? parseFlex(end)
        else {
            return "Error: Could not parse dates. Please use ISO-8601 format like 2026-04-18T15:00:00."
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes

        if let calName = calendarName, !calName.isEmpty {
            event.calendar = store.calendars(for: .event).first { $0.title == calName } ?? store.defaultCalendarForNewEvents
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        do {
            try store.save(event, span: .thisEvent)
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return "Created event '\(title)' on \(df.string(from: startDate)). Event ID: \(event.eventIdentifier ?? "unknown")"
        } catch {
            return "Error creating event: \(error.localizedDescription)"
        }
    }

    func listEvents(start: String, end: String) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Calendar access not granted."
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFullDate, .withTime]

        guard let startDate = formatter.date(from: start) ?? parseFlex(start),
              let endDate = formatter.date(from: end) ?? parseFlex(end)
        else {
            return "Error: Could not parse date range."
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return "No events found in this date range."
        }

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short

        return events.map { event in
            "- \(event.title ?? "Untitled") | \(df.string(from: event.startDate)) → \(df.string(from: event.endDate)) | ID: \(event.eventIdentifier ?? "")"
        }.joined(separator: "\n")
    }

    func deleteEvent(eventID: String) async -> String {
        guard await ensureAuthorized() else {
            return "Error: Calendar access not granted."
        }

        guard let event = store.event(withIdentifier: eventID) else {
            return "Error: Event not found with ID \(eventID)."
        }

        do {
            try store.remove(event, span: .thisEvent)
            return "Deleted event '\(event.title ?? "Untitled")'."
        } catch {
            return "Error deleting event: \(error.localizedDescription)"
        }
    }

    private func ensureAuthorized() async -> Bool {
        if authorized { return true }
        return await requestAccess()
    }

    private func parseFlex(_ str: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formatters {
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }
        return nil
    }
}
