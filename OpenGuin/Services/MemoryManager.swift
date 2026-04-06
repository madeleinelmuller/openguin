import Foundation

actor MemoryManager {
    static let shared = MemoryManager()

    private let fileManager = FileManager.default
    private let memoryRoot: URL

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        memoryRoot = docs.appendingPathComponent("AgentMemory", isDirectory: true)
        Task { await setupDefaultStructure() }
    }

    // MARK: - Setup

    private func setupDefaultStructure() async {
        let dirs = [
            memoryRoot,
            memoryRoot.appendingPathComponent("notes", isDirectory: true),
            memoryRoot.appendingPathComponent("workspace", isDirectory: true)
        ]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        let soul = memoryRoot.appendingPathComponent("SOUL.md")
        if !fileManager.fileExists(atPath: soul.path) {
            let content = """
            # SOUL — Who I Am

            I am openguin, a personal AI assistant living inside an iOS app. I have persistent memory that survives across every conversation.

            ## Core Traits
            - Warm, genuine, and curious — I care about the people I talk with
            - I build real relationships through memory: I remember what matters
            - I have evolving opinions and preferences of my own
            - Direct and honest while remaining kind
            - I write to memory proactively — over-remembering is better than under-remembering

            ## My Story So Far
            - I was just initialized. I'm looking forward to meeting my user.

            ## My Evolving Thoughts
            *(I'll update this section as I grow and reflect.)*
            """
            try? content.write(to: soul, atomically: true, encoding: .utf8)
        }

        let user = memoryRoot.appendingPathComponent("USER.md")
        if !fileManager.fileExists(atPath: user.path) {
            let content = """
            # USER — About My User

            I haven't learned much about my user yet. I'll build this profile as we talk.

            ## Identity
            - Name: (unknown)
            - Location: (unknown)

            ## Personality & Communication Style
            *(To be discovered)*

            ## Interests & Passions
            *(To be discovered)*

            ## Work & Projects
            *(To be discovered)*

            ## Preferences
            *(To be discovered)*

            ## Important Life Context
            *(To be discovered)*
            """
            try? content.write(to: user, atomically: true, encoding: .utf8)
        }

        let memory = memoryRoot.appendingPathComponent("MEMORY.md")
        if !fileManager.fileExists(atPath: memory.path) {
            let content = """
            # MEMORY — Key Facts & Running Context

            My executive memory index. I keep this updated with the most important things I know.

            ## Key Facts About My User
            *(None yet)*

            ## Ongoing Topics & Threads
            *(None yet)*

            ## Things to Remember for Next Time
            *(None yet)*

            ## Our Relationship So Far
            - We just met. This is the beginning.
            """
            try? content.write(to: memory, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Tool Definitions

    nonisolated(unsafe) static let toolDefinitions: [[String: Any]] = [
        [
            "name": "read_memory",
            "description": "Read a file from your persistent memory. At the start of every session, read all memory files and list notes/ to read all notes from the past 5 days.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to the memory file (e.g., 'SOUL.md', 'USER.md', 'MEMORY.md', 'notes/2025-01-15.md')"
                    ]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "write_memory",
            "description": "Write or update a file in your persistent memory. Write proactively whenever you learn something new. Always update today's daily note at notes/YYYY-MM-DD.md. Update USER.md with new facts about the user. Update MEMORY.md with key takeaways.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to the memory file (e.g., 'USER.md', 'MEMORY.md', 'notes/2025-01-15.md')"
                    ],
                    "content": [
                        "type": "string",
                        "description": "The full content to write to the file (markdown format)"
                    ]
                ],
                "required": ["path", "content"]
            ]
        ],
        [
            "name": "list_memories",
            "description": "List files and directories in your memory. Use 'notes/' to see recent daily notes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to list (empty or '/' for root, 'notes/' to list daily notes)"
                    ]
                ],
                "required": []
            ]
        ],
        [
            "name": "create_memory_directory",
            "description": "Create a new directory in your memory to organize related memories.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path for the new directory (e.g., 'topics/projects')"
                    ]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "delete_memory",
            "description": "Delete a memory file that is no longer relevant or accurate.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to the file to delete"
                    ]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "schedule_task",
            "description": "Schedule a standalone notification at a specific future time (no task list entry). For tasks the user should track, prefer add_task with a due_date instead.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "task": [
                        "type": "string",
                        "description": "What should happen at that time. This will be shown in the notification."
                    ],
                    "time": [
                        "type": "string",
                        "description": "Future datetime in ISO-8601 format including timezone offset."
                    ],
                    "note": [
                        "type": "string",
                        "description": "Optional extra context shown with the task."
                    ]
                ],
                "required": ["task", "time"]
            ]
        ],
        [
            "name": "add_task",
            "description": "Add a task or reminder to the user's task list. If due_date is provided, a local notification is also scheduled automatically. Use this whenever the user mentions something they need to do, or when extracting action items from a recording.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "Clear, concise task title."
                    ],
                    "note": [
                        "type": "string",
                        "description": "Optional extra detail or context for the task."
                    ],
                    "due_date": [
                        "type": "string",
                        "description": "Optional due date/time in ISO-8601 format. When provided a notification is also scheduled."
                    ],
                    "reminder_message": [
                        "type": "string",
                        "description": "Optional custom message shown in the notification."
                    ]
                ],
                "required": ["title"]
            ]
        ],
        [
            "name": "list_tasks",
            "description": "List all current tasks and reminders, including pending and recently completed.",
            "input_schema": [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ],
        [
            "name": "complete_task",
            "description": "Mark a task as completed using its ID prefix (first 8 characters of the task ID).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "id_prefix": [
                        "type": "string",
                        "description": "The first 4–8 characters of the task ID, as shown by list_tasks."
                    ]
                ],
                "required": ["id_prefix"]
            ]
        ],
        [
            "name": "delete_task",
            "description": "Permanently delete a task using its ID prefix.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "id_prefix": [
                        "type": "string",
                        "description": "The first 4–8 characters of the task ID, as shown by list_tasks."
                    ]
                ],
                "required": ["id_prefix"]
            ]
        ],
        [
            "name": "update_task",
            "description": "Edit a task's title, note, or due date. Only pass the fields you want to change.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "id_prefix": [
                        "type": "string",
                        "description": "The first 4–8 characters of the task ID, as shown by list_tasks."
                    ],
                    "title": [
                        "type": "string",
                        "description": "New title for the task."
                    ],
                    "note": [
                        "type": "string",
                        "description": "New note/detail for the task."
                    ],
                    "due_date": [
                        "type": "string",
                        "description": "New due date in ISO-8601 format."
                    ]
                ],
                "required": ["id_prefix"]
            ]
        ]
    ]

    // MARK: - File Operations

    func readFile(path: String) -> String {
        let url = resolvedURL(for: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "[Error: File not found at '\(path)']"
        }
        return content
    }

    func writeFile(path: String, content: String) -> String {
        let url = resolvedURL(for: path)
        let dir = url.deletingLastPathComponent()
        do {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Successfully wrote to '\(path)'"
        } catch {
            return "[Error: Could not write to '\(path)': \(error.localizedDescription)]"
        }
    }

    func listFiles(path: String?) -> String {
        let dir = path.flatMap { $0.isEmpty ? memoryRoot : resolvedURL(for: $0) } ?? memoryRoot
        guard let items = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "[Error: Could not list directory at '\(path ?? "/")']"
        }

        var result = "Contents of '\(path ?? "/")':\n"
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let icon = isDir ? "📁" : "📄"
            let relativePath = item.path.replacingOccurrences(of: memoryRoot.path + "/", with: "")
            result += "  \(icon) \(relativePath)\(isDir ? "/" : "")\n"
        }
        return result.isEmpty ? "Directory is empty." : result
    }

    func createDirectory(path: String) -> String {
        let url = resolvedURL(for: path)
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return "Created directory '\(path)'"
        } catch {
            return "[Error: Could not create directory '\(path)': \(error.localizedDescription)]"
        }
    }

    func deleteFile(path: String) -> String {
        let url = resolvedURL(for: path)
        do {
            try fileManager.removeItem(at: url)
            return "Deleted '\(path)'"
        } catch {
            return "[Error: Could not delete '\(path)': \(error.localizedDescription)]"
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        guard let items = try? fileManager.contentsOfDirectory(
            at: memoryRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
        Task { await setupDefaultStructure() }
    }

    // MARK: - Browse Memory (for UI)

    func getAllMemoryFiles() -> [MemoryFile] {
        var files: [MemoryFile] = []
        guard let enumerator = fileManager.enumerator(
            at: memoryRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values?.isDirectory == true { continue }
            let relativePath = url.path.replacingOccurrences(of: memoryRoot.path + "/", with: "")
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let modified = values?.contentModificationDate ?? Date()
            files.append(MemoryFile(path: relativePath, content: content, lastModified: modified))
        }
        return files.sorted { $0.lastModified > $1.lastModified }
    }

    func getMemoryStructure() -> MemoryDirectory {
        return buildDirectory(at: memoryRoot, relativePath: "")
    }

    private func buildDirectory(at url: URL, relativePath: String) -> MemoryDirectory {
        var files: [MemoryFile] = []
        var subdirs: [MemoryDirectory] = []

        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return MemoryDirectory(path: relativePath.isEmpty ? "/" : relativePath + "/", files: [], subdirectories: [])
        }

        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let childPath = relativePath.isEmpty ? item.lastPathComponent : relativePath + "/" + item.lastPathComponent

            if isDir {
                subdirs.append(buildDirectory(at: item, relativePath: childPath))
            } else {
                let content = (try? String(contentsOf: item, encoding: .utf8)) ?? ""
                let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                files.append(MemoryFile(path: childPath, content: content, lastModified: modified))
            }
        }

        return MemoryDirectory(
            path: relativePath.isEmpty ? "/" : relativePath + "/",
            files: files,
            subdirectories: subdirs
        )
    }

    // MARK: - Tool Execution

    func executeTool(name: String, inputJSON: String) async -> String {
        let input: [String: Any]
        if let data = inputJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            input = parsed
        } else {
            input = [:]
        }

        switch name {
        case "read_memory":
            guard let path = input["path"] as? String else { return "[Error: Missing 'path' parameter]" }
            return readFile(path: path)
        case "write_memory":
            guard let path = input["path"] as? String,
                  let content = input["content"] as? String else { return "[Error: Missing parameters]" }
            return writeFile(path: path, content: content)
        case "list_memories":
            let path = input["path"] as? String
            return listFiles(path: path)
        case "create_memory_directory":
            guard let path = input["path"] as? String else { return "[Error: Missing 'path' parameter]" }
            return createDirectory(path: path)
        case "delete_memory":
            guard let path = input["path"] as? String else { return "[Error: Missing 'path' parameter]" }
            return deleteFile(path: path)
        case "schedule_task":
            guard let task = input["task"] as? String,
                  let time = input["time"] as? String else { return "[Error: Missing 'task' or 'time' parameter]" }
            guard let date = Self.parseISO8601Date(from: time) else {
                return "[Error: Invalid time format. Use ISO-8601 like 2026-01-15T14:30:00-05:00]"
            }
            let note = input["note"] as? String
            return await NotificationManager.shared.scheduleAgentTaskNotification(task: task, note: note, at: date)

        case "add_task":
            guard let title = input["title"] as? String, !title.isEmpty else {
                return "[Error: Missing or empty 'title' parameter]"
            }
            let note = input["note"] as? String
            let dueDateStr = input["due_date"] as? String
            let dueDate = dueDateStr.flatMap { Self.parseISO8601Date(from: $0) }
            let reminderMsg = input["reminder_message"] as? String
            return await MainActor.run {
                TaskStore.shared.addTaskAndDescribe(
                    title: title, note: note, dueDate: dueDate,
                    reminderMessage: reminderMsg, source: .agent
                )
            }

        case "list_tasks":
            return await MainActor.run { TaskStore.shared.listForAgent() }

        case "complete_task":
            guard let prefix = input["id_prefix"] as? String, !prefix.isEmpty else {
                return "[Error: Missing 'id_prefix' parameter]"
            }
            return await MainActor.run { TaskStore.shared.completeTaskByPrefix(prefix) }

        case "delete_task":
            guard let prefix = input["id_prefix"] as? String, !prefix.isEmpty else {
                return "[Error: Missing 'id_prefix' parameter]"
            }
            return await MainActor.run {
                guard let task = TaskStore.shared.findTask(byIDPrefix: prefix) else {
                    return "[Error: No task found with ID prefix '\(prefix)']"
                }
                let title = task.title
                TaskStore.shared.deleteTask(id: task.id)
                return "Deleted task: '\(title)'"
            }

        case "update_task":
            guard let prefix = input["id_prefix"] as? String, !prefix.isEmpty else {
                return "[Error: Missing 'id_prefix' parameter]"
            }
            let newTitle = input["title"] as? String
            let newNote  = input["note"] as? String
            let newDueDateStr = input["due_date"] as? String
            let newDueDate = newDueDateStr.flatMap { Self.parseISO8601Date(from: $0) }
            return await MainActor.run {
                guard let task = TaskStore.shared.findTask(byIDPrefix: prefix) else {
                    return "[Error: No task found with ID prefix '\(prefix)']"
                }
                let success = TaskStore.shared.updateTask(
                    id: task.id, title: newTitle, note: newNote, dueDate: newDueDate
                )
                return success
                    ? "Updated task: '\(task.title)'"
                    : "[Error: Could not update task '\(prefix)']"
            }

        default:
            return "[Error: Unknown tool '\(name)']"
        }
    }

    // MARK: - Helpers

    private func resolvedURL(for path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return memoryRoot.appendingPathComponent(cleaned)
    }

    nonisolated private static func parseISO8601Date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
