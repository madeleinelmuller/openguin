import Foundation

enum AgentToolName: String, CaseIterable, Sendable {
    // Memory
    case readFile = "read_file"
    case writeFile = "write_file"
    case listFiles = "list_files"
    case deleteFile = "delete_file"
    case createDirectory = "create_directory"
    // Calendar
    case createEvent = "create_event"
    case listEvents = "list_events"
    case deleteEvent = "delete_event"
    // Reminders
    case createReminder = "create_reminder"
    case listReminders = "list_reminders"
    case completeReminder = "complete_reminder"
    case deleteReminder = "delete_reminder"
    // Web
    case webSearch = "web_search"
    case fetchURL = "fetch_url"
    // Code
    case executeCode = "execute_code"
    // System
    case getCurrentTime = "get_current_time"
    case getUserInfo = "get_user_info"
}

struct AgentTool: @unchecked Sendable {
    let name: AgentToolName
    let description: String
    let inputSchema: [String: Any]

    func anthropicBlock() -> [String: Any] {
        [
            "name": name.rawValue,
            "description": description,
            "input_schema": inputSchema
        ]
    }

    func openAIBlock() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name.rawValue,
                "description": description,
                "parameters": inputSchema
            ]
        ]
    }
}

struct ToolCall: Sendable {
    let id: String
    let name: AgentToolName
    let inputJSON: String
}
