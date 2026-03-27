#if canImport(Foundation)
import Foundation
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Shared Namespace to avoid top-level redeclarations across targets

enum OpenGuinSharedTypes {
    // MARK: - Live Activity Attributes (only when ActivityKit is available)
    #if canImport(ActivityKit)
    struct RecordingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var duration: TimeInterval
            var isTranscribing: Bool
        }
        var sessionName: String
    }
    #endif

    // MARK: - Task Snapshot

    /// Lightweight task snapshot shared between app and widgets via App Group.
    struct SharedTaskSnapshot: Codable, Sendable {
        let id: String
        let title: String
        let note: String?
        let dueDate: Date?
        let isCompleted: Bool
        let source: String
    }

    /// Reads task data from the shared App Group container.
    enum SharedDataManager {
        static let appGroupID = "group.com.openguin.app"

        private static var sharedDefaults: UserDefaults? {
            UserDefaults(suiteName: appGroupID)
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

// If consumers previously referenced the old top-level names, consider updating call sites to use:
// OpenGuinSharedTypes.SharedTaskSnapshot
// OpenGuinSharedTypes.SharedDataManager
// and when ActivityKit is available:
// OpenGuinSharedTypes.RecordingAttributes
