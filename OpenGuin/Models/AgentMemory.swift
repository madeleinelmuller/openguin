import Foundation
import SwiftUI

struct MemoryFile: Identifiable, Codable {
    var id: String { path }
    let path: String
    var content: String
    var lastModified: Date

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var isDirectory: Bool {
        path.hasSuffix("/")
    }

    var icon: String {
        if fileName == "about_me.md" { return "person.text.rectangle" }
        if fileName == "about_user.md" { return "person.crop.circle" }
        if fileName.hasSuffix(".md") { return "doc.text" }
        return "doc"
    }

    var color: Color {
        if fileName == "about_me.md" { return .blue }
        if fileName == "about_user.md" { return .green }
        return .orange
    }
}

struct MemoryDirectory: Identifiable {
    var id: String { path }
    let path: String
    var files: [MemoryFile]
    var subdirectories: [MemoryDirectory]

    var name: String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        return (trimmed as NSString).lastPathComponent
    }
}

enum MemoryToolCall: Codable {
    case readFile(path: String)
    case writeFile(path: String, content: String)
    case listFiles(path: String?)
    case createDirectory(path: String)
    case deleteFile(path: String)

    var toolName: String {
        switch self {
        case .readFile: return "read_memory"
        case .writeFile: return "write_memory"
        case .listFiles: return "list_memories"
        case .createDirectory: return "create_memory_directory"
        case .deleteFile: return "delete_memory"
        }
    }
}

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let input_schema: InputSchema

    struct InputSchema: Codable {
        let type: String
        let properties: [String: Property]
        let required: [String]
    }

    struct Property: Codable {
        let type: String
        let description: String
    }
}
