import Foundation
import ActivityKit

// MARK: - Live Activity

struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var duration: TimeInterval
    }
}
