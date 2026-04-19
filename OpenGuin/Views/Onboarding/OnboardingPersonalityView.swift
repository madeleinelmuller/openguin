import SwiftUI

struct OnboardingPersonalityView: View {
    @Binding var name: String
    let onNext: () -> Void
    @FocusState private var focused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                Text("What should I call you?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                Text("I'll remember your name — and everything else that matters — across every conversation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
            }

            // Name input
            GlassCard(cornerRadius: 20, padding: 20) {
                TextField("Your name", text: $name)
                    .font(.title3)
                    .focused($focused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .submitLabel(.continue)
                    .onSubmit { if !name.isEmpty { onNext() } }
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            // Continue button
            HapticButton(.medium, action: onNext) {
                Text(name.isEmpty ? "Skip" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        name.isEmpty ? Color.secondary : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .animation(.spring(response: 0.3), value: name.isEmpty)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { focused = true }
        }
    }
}

#Preview {
    @Previewable @State var name = ""
    OnboardingPersonalityView(name: $name, onNext: {})
}
