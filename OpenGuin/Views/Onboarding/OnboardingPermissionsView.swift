import SwiftUI
import EventKit
import Speech
import AVFoundation

struct OnboardingPermissionsView: View {
    let onNext: () -> Void
    @State private var appeared = false

    @State private var calendarGranted = false
    @State private var remindersGranted = false
    @State private var micGranted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                Text("A few permissions")
                    .font(.title.bold())
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.2), value: appeared)

                Text("These let Openguin create events, set reminders, and transcribe your voice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.3), value: appeared)
            }
            .padding(.bottom, 32)

            // Permission cards
            VStack(spacing: 12) {
                permissionCard(
                    icon: "calendar",
                    title: "Calendar & Reminders",
                    description: "Create events and reminders from conversations",
                    granted: calendarGranted && remindersGranted
                ) {
                    Task {
                        _ = await CalendarService.shared.requestAccess()
                        _ = await RemindersService.shared.requestAccess()
                        await checkStatuses()
                    }
                }

                permissionCard(
                    icon: "mic.fill",
                    title: "Microphone & Speech",
                    description: "Record voice memos and transcribe meetings",
                    granted: micGranted
                ) {
                    Task {
                        _ = await RecordingService().requestPermissions()
                        await checkStatuses()
                    }
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            HapticButton(.medium, action: onNext) {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut.delay(0.55), value: appeared)
        }
        .task { await checkStatuses() }
        .onAppear { appeared = true }
    }

    private func permissionCard(
        icon: String,
        title: String,
        description: String,
        granted: Bool,
        onGrant: @escaping () -> Void
    ) -> some View {
        GlassCard(cornerRadius: 20, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: granted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22))
                    .foregroundStyle(granted ? .green : Color.accentColor)
                    .frame(width: 36)
                    .animation(.spring(response: 0.4), value: granted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !granted {
                    HapticButton(.light, action: onGrant) {
                        Text("Grant")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
            }
        }
    }

    @MainActor
    private func checkStatuses() async {
        calendarGranted = EKEventStore.authorizationStatus(for: .event) == .fullAccess
            || EKEventStore.authorizationStatus(for: .event) == .authorized
        remindersGranted = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
            || EKEventStore.authorizationStatus(for: .reminder) == .authorized
        micGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    }
}

#Preview {
    OnboardingPermissionsView(onNext: {})
}
