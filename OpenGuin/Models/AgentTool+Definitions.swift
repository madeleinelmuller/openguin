import Foundation

extension AgentTool {
    static let allTools: [AgentTool] = [
        // MARK: Memory
        AgentTool(
            name: .readFile,
            description: "Read the contents of a file from the agent memory filesystem.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "File path relative to AgentMemory root (e.g. SOUL.md, notes/2026-04-18.md)"]
                ],
                "required": ["path"]
            ]
        ),
        AgentTool(
            name: .writeFile,
            description: "Write or overwrite a file in the agent memory filesystem.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "File path relative to AgentMemory root"],
                    "content": ["type": "string", "description": "The content to write"]
                ],
                "required": ["path", "content"]
            ]
        ),
        AgentTool(
            name: .listFiles,
            description: "List files and directories at a given path in the agent memory filesystem.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Directory path relative to AgentMemory root. Use empty string for root."]
                ],
                "required": ["path"]
            ]
        ),
        AgentTool(
            name: .deleteFile,
            description: "Delete a file from the agent memory filesystem.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "File path relative to AgentMemory root"]
                ],
                "required": ["path"]
            ]
        ),
        AgentTool(
            name: .createDirectory,
            description: "Create a directory in the agent memory filesystem.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "Directory path relative to AgentMemory root"]
                ],
                "required": ["path"]
            ]
        ),
        // MARK: Calendar
        AgentTool(
            name: .createEvent,
            description: "Create a calendar event in the user's Apple Calendar.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Event title"],
                    "start": ["type": "string", "description": "Start date/time in ISO-8601 format (e.g. 2026-04-18T15:00:00)"],
                    "end": ["type": "string", "description": "End date/time in ISO-8601 format"],
                    "notes": ["type": "string", "description": "Optional notes or description for the event"],
                    "calendar": ["type": "string", "description": "Optional calendar name. Leave empty for default."]
                ],
                "required": ["title", "start", "end"]
            ]
        ),
        AgentTool(
            name: .listEvents,
            description: "List calendar events in a date range from Apple Calendar.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "start": ["type": "string", "description": "Start of range in ISO-8601 format"],
                    "end": ["type": "string", "description": "End of range in ISO-8601 format"]
                ],
                "required": ["start", "end"]
            ]
        ),
        AgentTool(
            name: .deleteEvent,
            description: "Delete a calendar event by its identifier.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "eventID": ["type": "string", "description": "The event identifier returned by list_events"]
                ],
                "required": ["eventID"]
            ]
        ),
        // MARK: Reminders
        AgentTool(
            name: .createReminder,
            description: "Create a reminder in Apple Reminders.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Reminder title"],
                    "dueDate": ["type": "string", "description": "Optional due date in ISO-8601 format"],
                    "notes": ["type": "string", "description": "Optional notes"],
                    "list": ["type": "string", "description": "Optional list name. Leave empty for default."]
                ],
                "required": ["title"]
            ]
        ),
        AgentTool(
            name: .listReminders,
            description: "List incomplete reminders from Apple Reminders.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "list": ["type": "string", "description": "Optional list name to filter. Leave empty for all."]
                ],
                "required": []
            ]
        ),
        AgentTool(
            name: .completeReminder,
            description: "Mark a reminder as complete.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "reminderID": ["type": "string", "description": "The reminder identifier returned by list_reminders"]
                ],
                "required": ["reminderID"]
            ]
        ),
        AgentTool(
            name: .deleteReminder,
            description: "Delete a reminder.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "reminderID": ["type": "string", "description": "The reminder identifier returned by list_reminders"]
                ],
                "required": ["reminderID"]
            ]
        ),
        // MARK: Web
        AgentTool(
            name: .webSearch,
            description: "Search the web for current information. Use for time-sensitive queries, news, prices, or anything where training data may be stale.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "The search query"]
                ],
                "required": ["query"]
            ]
        ),
        AgentTool(
            name: .fetchURL,
            description: "Fetch the text content of a web page URL.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "url": ["type": "string", "description": "The URL to fetch"]
                ],
                "required": ["url"]
            ]
        ),
        // MARK: Code
        AgentTool(
            name: .executeCode,
            description: "Execute code or save a script to workspace. JavaScript runs directly on-device via JavaScriptCore. Python and shell scripts are saved to workspace/scripts/ for external execution.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "language": ["type": "string", "description": "Programming language: javascript, python, or shell"],
                    "code": ["type": "string", "description": "The code to execute or save"],
                    "filename": ["type": "string", "description": "Optional filename for saved scripts (without extension)"]
                ],
                "required": ["language", "code"]
            ]
        ),
        // MARK: System
        AgentTool(
            name: .getCurrentTime,
            description: "Get the current date and time.",
            inputSchema: [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        ),
        AgentTool(
            name: .getUserInfo,
            description: "Get the user's name and basic profile information.",
            inputSchema: [
                "type": "object",
                "properties": [:],
                "required": []
            ]
        )
    ]
}
