import AppIntents
import Foundation

// MARK: - Open App Intent

struct OpenOpenGuinIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open openguin"
    nonisolated static let description: IntentDescription = "Opens the openguin app"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Add Task Intent

struct AddTaskIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Add Task"
    nonisolated static let description: IntentDescription = "Creates a new task in openguin"

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Note", default: nil)
    var note: String?

    @Parameter(title: "Due Date", default: nil)
    var dueDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = TaskStore.shared.addTaskAndDescribe(
            title: taskTitle,
            note: note,
            dueDate: dueDate,
            source: .user
        )
        return .result(value: result)
    }
}

// MARK: - List Tasks Intent

struct ListTasksIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "List Tasks"
    nonisolated static let description: IntentDescription = "Lists all pending tasks from openguin"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = TaskStore.shared.listForAgent()
        return .result(value: result)
    }
}

// MARK: - Complete Task Intent

struct CompleteTaskIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Complete Task"
    nonisolated static let description: IntentDescription = "Marks a task as complete"

    @Parameter(title: "Task Title")
    var taskTitle: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = TaskStore.shared
        if let task = store.tasks.first(where: {
            $0.title.localizedCaseInsensitiveContains(taskTitle) && !$0.isCompleted
        }) {
            _ = store.completeTask(id: task.id)
            return .result(value: "Completed: \(task.title)")
        }
        return .result(value: "No matching task found for '\(taskTitle)'")
    }
}

// MARK: - Open Chat Intent (for widgets)

struct OpenChatIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open Chat"
    nonisolated static let description: IntentDescription = "Opens the openguin chat"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openChatFromNotification, object: nil)
        return .result()
    }
}

// MARK: - Open Tasks Intent (for widgets)

struct OpenTasksIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open Tasks"
    nonisolated static let description: IntentDescription = "Opens the openguin tasks view"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openTasksTab, object: nil)
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct OpenGuinShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenOpenGuinIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)"
            ],
            shortTitle: "Open openguin",
            systemImageName: "message"
        )
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "Remind me in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ListTasksIntent(),
            phrases: [
                "Show my tasks in \(.applicationName)",
                "List tasks in \(.applicationName)",
                "What do I need to do in \(.applicationName)"
            ],
            shortTitle: "List Tasks",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
                "Mark task done in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
    }
}
