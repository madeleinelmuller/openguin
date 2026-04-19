import SwiftUI
import Observation

enum OnboardingStep: Int, CaseIterable {
    case welcome, name, provider, permissions, complete
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .welcome
    var userName: String = ""

    var settingsVM = SettingsViewModel()

    func next() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            step = next
        }
    }

    func finish() {
        // Persist name
        SettingsManager.shared.userName = userName
        // Update USER.md with name
        Task {
            let content = await MemoryManager.shared.readFile(path: "USER.md")
            let updated = content.replacingOccurrences(of: "Name: (will update after onboarding)", with: "Name: \(userName)")
            _ = await MemoryManager.shared.writeFile(path: "USER.md", content: updated)
        }
        SettingsManager.shared.hasCompletedOnboarding = true
    }
}

struct OnboardingCoordinator: View {
    @State private var state = OnboardingState()

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch state.step {
            case .welcome:
                OnboardingWelcomeView(onNext: { state.next() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .name:
                OnboardingPersonalityView(name: $state.userName, onNext: { state.next() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .provider:
                OnboardingProviderView(vm: state.settingsVM, onNext: { state.next() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .permissions:
                OnboardingPermissionsView(onNext: { state.next() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .complete:
                OnboardingCompleteView(name: state.userName, onFinish: { state.finish() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: state.step)
    }
}
