import Foundation
import WidgetKit
import ActivityKit

// MARK: - Shared Types Namespace
// Both the main app and widget extension define their own copy of these types.
// The namespace enum ensures type names match across both targets for ActivityKit.

enum OpenGuinSharedTypes {

    // MARK: - Recording Live Activity Attributes

    struct RecordingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var duration: TimeInterval
            var isTranscribing: Bool
        }
        var sessionName: String
    }

    // MARK: - Task Snapshot

    /// Lightweight task snapshot for sharing between the main app and widgets
    /// via App Group UserDefaults.
    struct SharedTaskSnapshot: Codable, Sendable {
        let id: String
        let title: String
        let note: String?
        let dueDate: Date?
        let isCompleted: Bool
        let source: String
    }

    /// Manages reading/writing task data to the shared App Group container.
    enum SharedDataManager {
        static let appGroupID = "group.com.openguin.app"

        private static var sharedDefaults: UserDefaults? {
            UserDefaults(suiteName: appGroupID)
        }

        static func writeTasks(_ tasks: [SharedTaskSnapshot]) {
            guard let defaults = sharedDefaults,
                  let data = try? JSONEncoder().encode(tasks) else { return }
            defaults.set(data, forKey: "widgetTasks")
            WidgetCenter.shared.reloadAllTimelines()
        }

        static func readTasks() -> [SharedTaskSnapshot] {
            guard let defaults = sharedDefaults,
                  let data = defaults.data(forKey: "widgetTasks"),
                  let tasks = try? JSONDecoder().decode([SharedTaskSnapshot].self, from: data) else {
                return []
            }
            return tasks
        }

        static var pendingTasks: [SharedTaskSnapshot] {
            readTasks().filter { !$0.isCompleted }.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        }

        static var pendingCount: Int {
            readTasks().filter { !$0.isCompleted }.count
        }
    }
}
