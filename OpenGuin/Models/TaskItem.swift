import Foundation

@Observable
final class TaskItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var note: String?
    var dueDate: Date?
    var isCompleted: Bool
    var source: TaskSource
    let createdAt: Date
    var completedAt: Date?
    var reminderMessage: String?

    enum TaskSource: String, Codable {
        case agent       // Created autonomously by the LLM
        case transcript  // Extracted from a meeting/class recording
        case user        // Manually created by the user
    }

    init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        source: TaskSource = .agent,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reminderMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.source = source
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderMessage = reminderMessage
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, note, dueDate, isCompleted, source, createdAt, completedAt, reminderMessage
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(reminderMessage, forKey: .reminderMessage)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        source = try container.decode(TaskSource.self, forKey: .source)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        reminderMessage = try container.decodeIfPresent(String.self, forKey: .reminderMessage)
    }
}
