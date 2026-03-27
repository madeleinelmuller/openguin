import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget

struct TasksLockScreenWidget: Widget {
    let kind = "OpenGuinLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("See your task count and next task on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Lock Screen View

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TasksEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    // MARK: Circular (Small Lock Screen)

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "checklist")
                    .font(.caption)
                Text("\(entry.pendingCount)")
                    .font(.title3.weight(.bold))
            }
        }
        .widgetURL(URL(string: "openguin://tasks"))
    }

    // MARK: Rectangular (Medium Lock Screen)

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.caption2.weight(.semibold))
                Text("openguin")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(entry.pendingCount) pending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let nextTask = entry.tasks.first {
                HStack(spacing: 4) {
                    Circle()
                        .strokeBorder(.primary, lineWidth: 1)
                        .frame(width: 10, height: 10)
                    Text(nextTask.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                if let due = nextTask.dueDate {
                    Text(due, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("All clear!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "openguin://tasks"))
    }
}
