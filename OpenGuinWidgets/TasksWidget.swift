import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider

struct TasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: .now, tasks: [
            OpenGuinSharedTypes.SharedTaskSnapshot(id: "1", title: "Review notes", note: nil, dueDate: .now.addingTimeInterval(3600), isCompleted: false, source: "agent"),
            OpenGuinSharedTypes.SharedTaskSnapshot(id: "2", title: "Submit assignment", note: "Chapter 4", dueDate: .now.addingTimeInterval(7200), isCompleted: false, source: "transcript"),
        ], pendingCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        let tasks = OpenGuinSharedTypes.SharedDataManager.pendingTasks
        completion(TasksEntry(date: .now, tasks: Array(tasks.prefix(4)), pendingCount: tasks.count))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let tasks = OpenGuinSharedTypes.SharedDataManager.pendingTasks
        let entry = TasksEntry(date: .now, tasks: Array(tasks.prefix(4)), pendingCount: tasks.count)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Entry

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [OpenGuinSharedTypes.SharedTaskSnapshot]
    let pendingCount: Int
}

// MARK: - Widget

struct TasksWidget: Widget {
    let kind = "OpenGuinTasks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("See your upcoming tasks from openguin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TasksEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Tasks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.tasks.isEmpty {
                Spacer()
                Text("All clear!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(3), id: \.id) { task in
                        HStack(spacing: 6) {
                            Circle()
                                .strokeBorder(.secondary, lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                            Text(task.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                if entry.pendingCount > 3 {
                    Text("+\(entry.pendingCount - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(URL(string: "openguin://tasks"))
    }

    // MARK: Medium Widget

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checklist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Tasks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2), in: Capsule())
                }
            }

            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("All caught up!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(4), id: \.id) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .strokeBorder(.secondary, lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        if let due = task.dueDate {
                            Text(due, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(due < .now ? .red : .secondary)
                        }
                        sourceIcon(task.source)
                    }
                }
                if entry.pendingCount > 4 {
                    Text("+\(entry.pendingCount - 4) more tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(URL(string: "openguin://tasks"))
    }

    private func sourceIcon(_ source: String) -> some View {
        Group {
            switch source {
            case "agent":
                Image(systemName: "sparkles")
            case "transcript":
                Image(systemName: "waveform")
            default:
                EmptyView()
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}
