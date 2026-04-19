import Foundation

actor ToolDispatcher {
    static let shared = ToolDispatcher()

    private let memory = MemoryManager.shared
    private let calendar = CalendarService.shared
    private let reminders = RemindersService.shared
    private let webSearch = WebSearchService.shared
    private let sandbox = SandboxService.shared

    private init() {}

    func execute(name: AgentToolName, inputJSON: String) async -> String {
        let input = parseJSON(inputJSON)

        switch name {
        // MARK: Memory
        case .readFile:
            let path = input["path"] as? String ?? ""
            return await memory.readFile(path: path)

        case .writeFile:
            let path = input["path"] as? String ?? ""
            let content = input["content"] as? String ?? ""
            return await memory.writeFile(path: path, content: content)

        case .listFiles:
            let path = input["path"] as? String ?? ""
            return await memory.listFiles(path: path)

        case .deleteFile:
            let path = input["path"] as? String ?? ""
            return await memory.deleteFile(path: path)

        case .createDirectory:
            let path = input["path"] as? String ?? ""
            return await memory.createDirectory(path: path)

        // MARK: Calendar
        case .createEvent:
            let title = input["title"] as? String ?? "Untitled Event"
            let start = input["start"] as? String ?? ""
            let end = input["end"] as? String ?? ""
            let notes = input["notes"] as? String
            let calendarName = input["calendar"] as? String
            return await calendar.createEvent(title: title, start: start, end: end, notes: notes, calendarName: calendarName)

        case .listEvents:
            let start = input["start"] as? String ?? ""
            let end = input["end"] as? String ?? ""
            return await calendar.listEvents(start: start, end: end)

        case .deleteEvent:
            let eventID = input["eventID"] as? String ?? ""
            return await calendar.deleteEvent(eventID: eventID)

        // MARK: Reminders
        case .createReminder:
            let title = input["title"] as? String ?? "Untitled"
            let dueDate = input["dueDate"] as? String
            let notes = input["notes"] as? String
            let list = input["list"] as? String
            return await reminders.createReminder(title: title, dueDate: dueDate, notes: notes, listName: list)

        case .listReminders:
            let list = input["list"] as? String
            return await reminders.listReminders(listName: list)

        case .completeReminder:
            let id = input["reminderID"] as? String ?? ""
            return await reminders.completeReminder(reminderID: id)

        case .deleteReminder:
            let id = input["reminderID"] as? String ?? ""
            return await reminders.deleteReminder(reminderID: id)

        // MARK: Web
        case .webSearch:
            let query = input["query"] as? String ?? ""
            return await webSearch.search(query: query)

        case .fetchURL:
            let url = input["url"] as? String ?? ""
            return await webSearch.fetchURL(url)

        // MARK: Code
        case .executeCode:
            let language = input["language"] as? String ?? "javascript"
            let code = input["code"] as? String ?? ""
            let filename = input["filename"] as? String
            return await sandbox.execute(language: language, code: code, filename: filename)

        // MARK: System
        case .getCurrentTime:
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            return "Current time: \(formatter.string(from: .now)) (\(TimeZone.current.identifier))"

        case .getUserInfo:
            let settings = SettingsManager.shared
            let name = settings.userName.isEmpty ? "unknown" : settings.userName
            return "User name: \(name)\nProvider: \(settings.provider.displayName)\nModel: \(settings.activeModel(for: settings.provider))"
        }
    }

    func executeAll(_ tools: [ToolCall]) async -> [(id: String, result: String)] {
        var results: [(id: String, result: String)] = []
        for tool in tools {
            let result = await execute(name: tool.name, inputJSON: tool.inputJSON)
            results.append((id: tool.id, result: result))
        }
        return results
    }

    private func parseJSON(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }
}
