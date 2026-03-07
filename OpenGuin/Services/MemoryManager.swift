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
            try? writeEncryptedString(content, to: soul)
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
            try? writeEncryptedString(content, to: user)
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
            try? writeEncryptedString(content, to: memory)
        }
    }

    // MARK: - Tool Definitions

    nonisolated(unsafe) static let toolDefinitions: [[String: Any]] = [
        [
            "name": "read_memory",
            "description": "Read a file from your persistent memory. At the start of every session, read SOUL.md, USER.md, and MEMORY.md, then list notes/ for recent daily notes.",
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
            "description": "Schedule a local reminder or proactive check-in for a specific future time. Notifications still fire even if the app is closed. Use ISO-8601 datetime like '2026-01-15T14:30:00-05:00'.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "task": [
                        "type": "string",
                        "description": "Internal purpose of the reminder or follow-up."
                    ],
                    "time": [
                        "type": "string",
                        "description": "Future datetime in ISO-8601 format including timezone offset."
                    ],
                    "note": [
                        "type": "string",
                        "description": "Optional extra context shown with the task."
                    ],
                    "title": [
                        "type": "string",
                        "description": "Optional short notification title shown to the user."
                    ],
                    "user_message": [
                        "type": "string",
                        "description": "Optional concise message written directly to the user. Use this for natural check-ins."
                    ]
                ],
                "required": ["task", "time"]
            ]
        ]
    ]

    // MARK: - File Operations

    func readFile(path: String) -> String {
        let url = resolvedURL(for: path)
        guard let content = try? readDecryptedString(from: url) else {
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
            try writeEncryptedString(content, to: url)
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

        if items.isEmpty {
            return "Directory is empty."
        }

        var result = "Contents of '\(path ?? "/")':\n"
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let icon = isDir ? "📁" : "📄"
            let relativePath = item.path.replacingOccurrences(of: memoryRoot.path + "/", with: "")
            result += "  \(icon) \(relativePath)\(isDir ? "/" : "")\n"
        }
        return result
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
            let content = (try? readDecryptedString(from: url)) ?? ""
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
                let content = (try? readDecryptedString(from: item)) ?? ""
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
            let title = input["title"] as? String
            let userMessage = input["user_message"] as? String
            let result = await NotificationManager.shared.scheduleAgentTaskNotification(
                task: task,
                note: note,
                title: title,
                userMessage: userMessage,
                at: date
            )
            await appendReminderLog(task: task, note: note, userMessage: userMessage, scheduledFor: date)
            return result
        default:
            return "[Error: Unknown tool '\(name)']"
        }
    }

    // MARK: - Helpers

    private func resolvedURL(for path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return memoryRoot.appendingPathComponent(cleaned)
    }

    private func writeEncryptedString(_ content: String, to url: URL) throws {
        let plaintext = Data(content.utf8)
        let ciphertext = try SecurityManager.shared.encrypt(plaintext)
        try ciphertext.write(to: url, options: .atomic)
    }

    private func readDecryptedString(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        if let decrypted = try? SecurityManager.shared.decrypt(data),
           let string = String(data: decrypted, encoding: .utf8) {
            return string
        }

        if let plaintext = String(data: data, encoding: .utf8) {
            // Migrate older plaintext files into encrypted form on first read.
            try? writeEncryptedString(plaintext, to: url)
            return plaintext
        }

        throw SecurityManagerError.decryptionFailed
    }

    private func appendReminderLog(task: String, note: String?, userMessage: String?, scheduledFor date: Date) async {
        let logURL = resolvedURL(for: "REMINDERS.md")
        let existing = (try? readDecryptedString(from: logURL)) ?? """
        # REMINDERS

        A running log of reminders and proactive check-ins I have scheduled for the user.
        """

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var entry = "\n- \(formatter.string(from: date)) — \(task)"
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry += " | note: \(note.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        if let userMessage, !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry += " | user_message: \(userMessage.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        try? writeEncryptedString(existing + entry, to: logURL)
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
