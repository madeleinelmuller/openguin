import SwiftUI

struct OnboardingProviderView: View {
    @Bindable var vm: SettingsViewModel
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                Text("Connect your AI")
                    .font(.title.bold())
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.2), value: appeared)

                Text("Choose a provider and add your API key, or use a local model with Ollama.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.3), value: appeared)
            }
            .padding(.bottom, 32)

            // Provider form in a glass card
            GlassCard(cornerRadius: 24, padding: 20) {
                VStack(spacing: 0) {
                    Form {
                        ProviderSettingsView(vm: vm)
                    }
                    .scrollDisabled(true)
                    .frame(height: 280)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            VStack(spacing: 12) {
                HapticButton(.medium, action: onNext) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Button("I'll set this up later") {
                    onNext()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut.delay(0.55), value: appeared)
        }
        .onAppear { appeared = true }
    }
}
