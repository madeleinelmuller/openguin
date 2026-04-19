import ActivityKit
import WidgetKit
import SwiftUI

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen / banner view
            HStack(spacing: 12) {
                Image(systemName: context.state.isRecording ? "mic.fill" : "waveform")
                    .foregroundStyle(context.state.isRecording ? .red : .primary)
                    .symbolEffect(.pulse, isActive: context.state.isRecording)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isRecording ? "Recording" : "Transcribing…")
                        .font(.headline)
                    if context.state.isRecording {
                        Text(timerInterval: Date()...Date().addingTimeInterval(context.state.duration), countsDown: false)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("Openguin")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color.accentColor.opacity(0.15))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, isActive: context.state.isRecording)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isRecording {
                        Text(timerInterval: Date()...Date().addingTimeInterval(context.state.duration), countsDown: false)
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isRecording ? "Recording…" : "Transcribing…")
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: context.state.isRecording)
            } compactTrailing: {
                if context.state.isRecording {
                    Text(timerInterval: Date()...Date().addingTimeInterval(context.state.duration), countsDown: false)
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}
