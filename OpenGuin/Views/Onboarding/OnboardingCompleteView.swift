import SwiftUI

struct OnboardingCompleteView: View {
    let name: String
    let onFinish: () -> Void
    @State private var appeared = false

    private var greeting: String {
        name.isEmpty ? "You're all set!" : "You're all set, \(name)!"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration penguin
            CelebrationPenguin(size: 130)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(.spring(response: 0.7, dampingFraction: 0.5).delay(0.1), value: appeared)
                .padding(.bottom, 36)

            Text(greeting)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3), value: appeared)

            Text("I've been waiting to meet you.\nLet's get started.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.45), value: appeared)

            Spacer()

            HapticButton(.heavy, action: onFinish) {
                Text("Start chatting")
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
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.6), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    OnboardingCompleteView(name: "Maddie", onFinish: {})
}
