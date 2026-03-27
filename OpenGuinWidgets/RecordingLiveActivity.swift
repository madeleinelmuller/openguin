import ActivityKit
import WidgetKit
import SwiftUI

// Uses OpenGuinSharedTypes.RecordingAttributes defined in SharedTypes.swift

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OpenGuinSharedTypes.RecordingAttributes.self) { context in
            // Lock Screen / Notification Banner UI
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(context.state.isTranscribing ? Color.blue.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: context.state.isTranscribing ? "waveform" : "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(context.state.isTranscribing ? .blue : .red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.isTranscribing ? "Transcribing…" : "Recording")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(context.attributes.sessionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !context.state.isTranscribing {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDuration(context.state.duration))
                            .font(.system(.callout, design: .monospaced).weight(.medium))
                            .foregroundStyle(.primary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    ProgressView()
                        .tint(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(Color(white: 0.08, opacity: 0.95))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isTranscribing ? "waveform" : "mic.fill")
                            .font(.title3)
                            .foregroundStyle(context.state.isTranscribing ? .blue : .red)
                        Text(context.state.isTranscribing ? "Transcribing" : "Recording")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.isTranscribing {
                        Text(formatDuration(context.state.duration))
                            .font(.system(.callout, design: .monospaced).weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.trailing, 4)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("openguin")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !context.state.isTranscribing {
                            HStack(spacing: 4) {
                                Circle().fill(.red).frame(width: 5, height: 5)
                                Text("Tap to stop").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

            } compactLeading: {
                Image(systemName: context.state.isTranscribing ? "waveform" : "mic.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(context.state.isTranscribing ? .blue : .red)

            } compactTrailing: {
                if context.state.isTranscribing {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text(formatDuration(context.state.duration))
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                }

            } minimal: {
                Image(systemName: context.state.isTranscribing ? "waveform" : "mic.fill")
                    .font(.caption2)
                    .foregroundStyle(context.state.isTranscribing ? .blue : .red)
            }
        }
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let m = Int(duration) / 60
    let s = Int(duration) % 60
    return String(format: "%d:%02d", m, s)
}
