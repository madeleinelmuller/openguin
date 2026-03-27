import SwiftUI

struct SplashScreenView: View {
    var onDismiss: () -> Void

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var body: some View {
        ZStack {
            RainbowBlobsBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + title
                VStack(spacing: 16) {
                    Text("🐧")
                        .font(.system(size: 72))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    VStack(spacing: 6) {
                        Text("openguin")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("Your intelligent companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(logoOpacity)
                }

                Spacer()

                // Feature cards
                VStack(spacing: 14) {
                    featureCard(
                        icon: "brain.head.profile",
                        iconColor: .purple,
                        title: "Persistent Memory",
                        description: "openguin remembers you across every conversation — your preferences, notes, and life context."
                    )

                    featureCard(
                        icon: "bell.badge",
                        iconColor: .orange,
                        title: "Smart Reminders",
                        description: "Ask openguin to remind you of anything. Tap a reminder notification to continue the conversation."
                    )
                }
                .padding(.horizontal, 24)
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()

                // Get Started button
                Button {
                    onDismiss()
                } label: {
                    Text("Get Started")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassEffect(
                            GlassEffect.regular.tint(.blue).interactive(),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.smooth.delay(0.4)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
    }

    private func featureCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .glassEffect(
                    GlassEffect.regular.tint(iconColor.opacity(0.15)),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassEffect(GlassEffect.regular, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    SplashScreenView(onDismiss: {})
}
