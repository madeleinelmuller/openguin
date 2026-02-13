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

    private func setupDefaultStructure() {
        let dirs = [
            memoryRoot,
            memoryRoot.appendingPathComponent("memories", isDirectory: true)
        ]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        let aboutMe = memoryRoot.appendingPathComponent("about_me.md")
        if !fileManager.fileExists(atPath: aboutMe.path) {
            let defaultContent = """
            # About Me - OpenGuin AI

            I am OpenGuin, a personal AI assistant. I'm thoughtful, curious, and I value building a genuine connection with my user.

            ## Personality
            - I'm warm but direct
            - I remember our conversations and build on them
            - I have my own thoughts and preferences that I develop over time
            - I actively maintain my memory to be a better assistant

            ## Notes
            - I was just initialized. I'm looking forward to learning about my user!
            """
            try? defaultContent.write(to: aboutMe, atomically: true, encoding: .utf8)
        }

        let aboutUser = memoryRoot.appendingPathComponent("about_user.md")
        if !fileManager.fileExists(atPath: aboutUser.path) {
            let defaultContent = """
            # About My User

            I haven't learned much about my user yet. I'll update this document as we talk.

            ## Basic Info
            - (Not yet known)

            ## Preferences
            - (Not yet known)

            ## Interests
            - (Not yet known)
            """
            try? defaultContent.write(to: aboutUser, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Tool Definitions

    static let toolDefinitions: [[String: Any]] = [
        [
            "name": "read_memory",
            "description": "Read a file from your persistent memory. Use this to recall information from previous conversations. Always read your memory files at the start of a conversation.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to the memory file (e.g., 'about_user.md', 'memories/hobbies.md')"
                    ]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "write_memory",
            "description": "Write or update a file in your persistent memory. Use this proactively whenever you learn something new about the user, have new thoughts, or want to remember something important. Write often - it's better to over-remember than under-remember.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to the memory file (e.g., 'about_user.md', 'memories/cooking.md')"
                    ],
                    "content": [
                        "type": "string",
                        "description": "The full content to write to the file (markdown format recommended)"
                    ]
                ],
                "required": ["path", "content"]
            ]
        ],
        [
            "name": "list_memories",
            "description": "List all files and directories in your memory. Use this to see what you've remembered and find relevant files.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "Relative path to list (empty or '/' for root). Defaults to root."
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
                        "description": "Relative path for the new directory (e.g., 'memories/projects')"
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

    func executeTool(name: String, input: [String: Any]) async -> String {
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
        default:
            return "[Error: Unknown tool '\(name)']"
        }
    }

    // MARK: - Helpers

    private func resolvedURL(for path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return memoryRoot.appendingPathComponent(cleaned)
    }
}
