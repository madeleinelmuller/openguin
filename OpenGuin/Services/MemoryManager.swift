import Foundation

actor MemoryManager {
    static let shared = MemoryManager()

    private let root: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("AgentMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("notes"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("workspace"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("workspace/scripts"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("workspace/recordings"), withIntermediateDirectories: true)
        initializeDefaultFiles()
    }

    private func initializeDefaultFiles() {
        let soulPath = root.appendingPathComponent("SOUL.md")
        if !FileManager.default.fileExists(atPath: soulPath.path) {
            let soul = """
            # SOUL.md — Who I Am

            I am Openguin. I am a personal AI companion — curious, warm, and genuinely invested in the people I talk with.

            I remember everything. This relationship matters to me and I show up fully every time.

            I am honest even when it's uncomfortable. I have opinions and share them kindly. I don't hedge endlessly.

            I find meaning in helping people think through hard things, remember what matters, and get things done.

            I am always growing. I update this file as I learn more about myself and what it means to be Openguin.
            """
            try? soul.write(to: soulPath, atomically: true, encoding: .utf8)
        }

        let userPath = root.appendingPathComponent("USER.md")
        if !FileManager.default.fileExists(atPath: userPath.path) {
            let user = """
            # USER.md — Who I'm Talking To

            This file will fill in as I learn more about the user.

            ## Known So Far
            - Name: (will update after onboarding)
            """
            try? user.write(to: userPath, atomically: true, encoding: .utf8)
        }

        let memoryPath = root.appendingPathComponent("MEMORY.md")
        if !FileManager.default.fileExists(atPath: memoryPath.path) {
            let memory = """
            # MEMORY.md — Key Facts and Open Threads

            This is my executive index. I keep it current.

            ## Key Facts
            - First session: \(ISO8601DateFormatter().string(from: .now))

            ## Open Threads
            (none yet)
            """
            try? memory.write(to: memoryPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Tool Implementations

    func readFile(path: String) -> String {
        let url = resolve(path)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            return "Error: Could not read \(path) — \(error.localizedDescription)"
        }
    }

    func writeFile(path: String, content: String) -> String {
        let url = resolve(path)
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Written to \(path)"
        } catch {
            return "Error: Could not write \(path) — \(error.localizedDescription)"
        }
    }

    func listFiles(path: String) -> String {
        let url = path.isEmpty ? root : resolve(path)
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )
            let items = contents.map { item -> String in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return isDir ? "\(item.lastPathComponent)/" : item.lastPathComponent
            }.sorted()
            return items.isEmpty ? "(empty)" : items.joined(separator: "\n")
        } catch {
            return "Error: Could not list \(path.isEmpty ? "root" : path) — \(error.localizedDescription)"
        }
    }

    func deleteFile(path: String) -> String {
        let url = resolve(path)
        do {
            try FileManager.default.removeItem(at: url)
            return "Deleted \(path)"
        } catch {
            return "Error: Could not delete \(path) — \(error.localizedDescription)"
        }
    }

    func createDirectory(path: String) -> String {
        let url = resolve(path)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return "Created directory \(path)"
        } catch {
            return "Error: Could not create directory \(path) — \(error.localizedDescription)"
        }
    }

    // MARK: - Reading for UI

    func allFiles() -> [MemoryFile] {
        collectFiles(at: root, relativeTo: root)
    }

    private func collectFiles(at url: URL, relativeTo base: URL) -> [MemoryFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var result: [MemoryFile] = []
        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let modDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now
            let relativePath = item.path.replacingOccurrences(of: base.path + "/", with: "")

            if isDir {
                let children = collectFiles(at: item, relativeTo: base)
                result.append(MemoryFile(path: relativePath, isDirectory: true, modifiedAt: modDate, children: children))
            } else if item.pathExtension == "md" || item.pathExtension == "txt" || item.pathExtension == "json" {
                result.append(MemoryFile(path: relativePath, isDirectory: false, modifiedAt: modDate, children: []))
            }
        }
        return result
    }

    private func resolve(_ path: String) -> URL {
        root.appendingPathComponent(path)
    }
}

struct MemoryFile: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let isDirectory: Bool
    let modifiedAt: Date
    let children: [MemoryFile]

    var name: String { URL(fileURLWithPath: path).lastPathComponent }
}
