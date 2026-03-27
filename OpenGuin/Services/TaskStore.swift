import Foundation
import WidgetKit

@Observable
@MainActor
final class TaskStore {
    static let shared = TaskStore()

    var tasks: [TaskItem] = []

    var pendingTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    private let saveURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("tasks.json")
        load()
    }

    // MARK: - CRUD

    func addTask(title: String, note: String? = nil, dueDate: Date? = nil, reminderMessage: String? = nil, source: TaskItem.TaskSource = .agent) -> TaskItem {
        let task = TaskItem(title: title, note: note, dueDate: dueDate, source: source, reminderMessage: reminderMessage)
        tasks.append(task)
        save()

        // Schedule a reminder notification if there's a due date
        if let dueDate, dueDate > Date() {
            Task {
                _ = await NotificationManager.shared.scheduleAgentTaskNotification(
                    task: title,
                    note: note,
                    title: "Reminder",
                    userMessage: reminderMessage ?? title,
                    at: dueDate
                )
            }
        }

        return task
    }

    func completeTask(id: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == id }) else { return false }
        task.isCompleted = true
        task.completedAt = Date()
        save()
        return true
    }

    func uncompleteTask(id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        task.isCompleted = false
        task.completedAt = nil
        save()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func updateTask(id: UUID, title: String? = nil, note: String? = nil, dueDate: Date? = nil) -> Bool {
        guard let task = tasks.first(where: { $0.id == id }) else { return false }
        if let title { task.title = title }
        if let note { task.note = note }
        if let dueDate { task.dueDate = dueDate }
        save()
        return true
    }

    /// Returns a formatted string of all tasks for the LLM to read.
    func listForAgent() -> String {
        if tasks.isEmpty { return "No tasks yet." }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var result = "## Pending Tasks\n"
        let pending = pendingTasks
        if pending.isEmpty {
            result += "None\n"
        } else {
            for task in pending {
                let due = task.dueDate.map { " (due: \(formatter.string(from: $0)))" } ?? ""
                let note = task.note.map { " — \($0)" } ?? ""
                result += "- [\(task.id.uuidString.prefix(8))] \(task.title)\(due)\(note) [source: \(task.source.rawValue)]\n"
            }
        }

        let completed = completedTasks.prefix(10)
        if !completed.isEmpty {
            result += "\n## Recently Completed\n"
            for task in completed {
                result += "- ~\(task.title)~ (completed \(formatter.string(from: task.completedAt ?? task.createdAt)))\n"
            }
        }

        return result
    }

    /// Find a task by partial ID prefix match (for agent use).
    func findTask(byIDPrefix prefix: String) -> TaskItem? {
        let lower = prefix.lowercased()
        return tasks.first { $0.id.uuidString.lowercased().hasPrefix(lower) }
    }

    /// Add a task and return a description string (Sendable-safe for cross-actor calls).
    func addTaskAndDescribe(title: String, note: String? = nil, dueDate: Date? = nil, reminderMessage: String? = nil, source: TaskItem.TaskSource = .agent) -> String {
        let task = addTask(title: title, note: note, dueDate: dueDate, reminderMessage: reminderMessage, source: source)
        let dueSuffix = dueDate.map { " (due: \($0.formatted()))" } ?? ""
        let reminderSuffix = reminderMessage != nil ? " [notification scheduled]" : ""
        return "Created task/reminder: '\(title)'\(dueSuffix)\(reminderSuffix) [id: \(task.id.uuidString.prefix(8))]"
    }

    /// Complete a task by ID prefix and return a result string (Sendable-safe).
    func completeTaskByPrefix(_ prefix: String) -> String {
        guard let task = findTask(byIDPrefix: prefix) else {
            return "[Error: No task found with ID prefix '\(prefix)']"
        }
        let title = task.title
        let success = completeTask(id: task.id)
        return success ? "Completed task: '\(title)'" : "[Error: Could not complete task]"
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(tasks)
            let encrypted = try SecurityManager.shared.encrypt(data)
            try encrypted.write(to: saveURL, options: .atomic)
        } catch {
            print("[TaskStore] Save error: \(error)")
        }
        syncToWidgets()
    }

    /// Writes a lightweight snapshot of tasks to the App Group container
    /// so widgets can display current task data.
    private func syncToWidgets() {
        let snapshots = tasks.map { task in
            OpenGuinSharedTypes.SharedTaskSnapshot(
                id: task.id.uuidString,
                title: task.title,
                note: task.note,
                dueDate: task.dueDate,
                isCompleted: task.isCompleted,
                source: task.source.rawValue
            )
        }
        OpenGuinSharedTypes.SharedDataManager.writeTasks(snapshots)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            let decrypted = try SecurityManager.shared.decrypt(data)
            tasks = try JSONDecoder().decode([TaskItem].self, from: decrypted)
        } catch {
            // Try plaintext fallback
            if let data = try? Data(contentsOf: saveURL),
               let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
                tasks = decoded
                save() // Re-encrypt
            } else {
                print("[TaskStore] Load error: \(error)")
            }
        }
    }
}
