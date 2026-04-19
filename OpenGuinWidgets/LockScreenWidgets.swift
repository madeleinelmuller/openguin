import WidgetKit
import SwiftUI
import AppIntents

struct OpenGuinLockScreenWidget: Widget {
    let kind = "OpenGuinLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Openguin")
        .description("Quick access to Openguin.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenEntry: TimelineEntry {
    let date: Date
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry { LockScreenEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) { completion(LockScreenEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        completion(Timeline(entries: [LockScreenEntry(date: .now)], policy: .never))
    }
}

struct LockScreenWidgetView: View {
    let entry: LockScreenEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 22, weight: .medium))
                .widgetURL(URL(string: "openguin://chat"))
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .medium))
                Text("Openguin")
                    .font(.headline)
            }
            .widgetURL(URL(string: "openguin://chat"))
        default:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .widgetURL(URL(string: "openguin://chat"))
        }
    }
}
