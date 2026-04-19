import SwiftUI

/// Animates the two-layer openguin SVG icon.
/// Layer one rotates slowly; layer two counter-rotates slightly faster for a fluid, organic feel.
struct LoadingPenguin: View {
    var size: CGFloat = 80
    var isAnimating: Bool = true

    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Image("openguin layer one")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation1))

            Image("openguin layer two")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation2))
        }
        .scaleEffect(scale)
        .onAppear {
            guard isAnimating else { return }
            startAnimating()
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue { startAnimating() } else { stopAnimating() }
        }
    }

    private func startAnimating() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation1 = 360
        }
        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
            rotation2 = -360
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            scale = 1.06
        }
    }

    private func stopAnimating() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            rotation1 = 0
            rotation2 = 0
            scale = 1.0
        }
    }
}

/// A spring-bounce celebratory variant used on the onboarding complete screen.
struct CelebrationPenguin: View {
    var size: CGFloat = 120

    @State private var bounce: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        Image("openguin layer one")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .overlay(
                Image("openguin layer two")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
            )
            .offset(y: bounce)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.4).repeatForever(autoreverses: true)) {
                    bounce = -18
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    rotation = 15
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingPenguin(size: 80)
        CelebrationPenguin(size: 120)
    }
    .padding()
}
