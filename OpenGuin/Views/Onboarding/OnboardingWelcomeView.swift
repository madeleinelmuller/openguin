import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Penguin icon
            LoadingPenguin(size: 100)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1), value: appeared)
                .padding(.bottom, 32)

            // Title
            Text("openguin")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.25), value: appeared)

            Text("Your AI companion that remembers")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            // CTA
            HapticButton(.medium, action: onNext) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.55), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    OnboardingWelcomeView(onNext: {})
}
