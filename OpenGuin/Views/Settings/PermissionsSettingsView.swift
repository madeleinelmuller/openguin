import SwiftUI
import EventKit
import Speech

struct PermissionsSettingsView: View {
    @State private var calendarStatus: EKAuthorizationStatus = .notDetermined
    @State private var remindersStatus: EKAuthorizationStatus = .notDetermined
    @State private var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var body: some View {
        Section("Permissions") {
            permissionRow(
                title: "Calendar",
                description: "Create and view calendar events",
                icon: "calendar",
                granted: calendarStatus == .fullAccess || calendarStatus == .authorized
            ) {
                Task {
                    _ = await CalendarService.shared.requestAccess()
                    await loadStatuses()
                }
            }

            permissionRow(
                title: "Reminders",
                description: "Create and manage reminders",
                icon: "bell",
                granted: remindersStatus == .fullAccess || remindersStatus == .authorized
            ) {
                Task {
                    _ = await RemindersService.shared.requestAccess()
                    await loadStatuses()
                }
            }

            permissionRow(
                title: "Microphone & Speech",
                description: "Record and transcribe voice memos",
                icon: "mic",
                granted: speechStatus == .authorized
            ) {
                Task {
                    SFSpeechRecognizer.requestAuthorization { _ in }
                    AVAudioApplication.requestRecordPermission { _ in }
                    await loadStatuses()
                }
            }
        }
        .task { await loadStatuses() }
    }

    private func permissionRow(
        title: String,
        description: String,
        icon: String,
        granted: Bool,
        onGrant: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(granted ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button("Grant", action: onGrant)
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .animation(.spring(response: 0.3), value: granted)
    }

    @MainActor
    private func loadStatuses() async {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
    }
}
