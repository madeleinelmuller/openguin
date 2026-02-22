import SwiftUI

struct AnimatedRainbowBackground: View {
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base white background
            Color.white.opacity(0.98)
                .ignoresSafeArea()

            // Bottom animated rainbow blob area
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Multiple animated blobs with different colors and phases
                    // Red blob
                    Blob(phase: animationPhase * 0.8, color: .red.opacity(0.25), scale: 1.2, offsetX: -0.3, offsetY: 0.2)
                        .blur(radius: 100)

                    // Orange blob
                    Blob(phase: animationPhase * 0.9, color: .orange.opacity(0.22), scale: 1.3, offsetX: -0.1, offsetY: 0.1)
                        .blur(radius: 110)

                    // Yellow blob
                    Blob(phase: animationPhase, color: .yellow.opacity(0.20), scale: 1.1, offsetX: 0.15, offsetY: 0.25)
                        .blur(radius: 105)

                    // Green blob
                    Blob(phase: animationPhase * 1.1, color: .green.opacity(0.20), scale: 1.25, offsetX: 0.35, offsetY: 0.15)
                        .blur(radius: 115)

                    // Cyan blob
                    Blob(phase: animationPhase * 0.85, color: .cyan.opacity(0.18), scale: 1.15, offsetX: -0.2, offsetY: 0.0)
                        .blur(radius: 108)

                    // Blue blob
                    Blob(phase: animationPhase * 1.05, color: .blue.opacity(0.20), scale: 1.2, offsetX: 0.25, offsetY: -0.1)
                        .blur(radius: 112)

                    // Purple blob
                    Blob(phase: animationPhase * 0.95, color: .purple.opacity(0.18), scale: 1.3, offsetX: 0.0, offsetY: 0.3)
                        .blur(radius: 120)

                    // Additional overlays for depth
                    Blob(phase: animationPhase * 0.7, color: .red.opacity(0.12), scale: 1.4, offsetX: 0.2, offsetY: 0.2)
                        .blur(radius: 130)

                    Blob(phase: animationPhase * 1.15, color: .blue.opacity(0.12), scale: 1.35, offsetX: -0.3, offsetY: 0.1)
                        .blur(radius: 125)
                }
                .frame(height: 500)
                .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animationPhase = 2 * .pi
            }
        }
    }
}

// MARK: - Blob Shape

struct Blob: Shape {
    let phase: CGFloat
    let color: Color
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = rect.midX + rect.width * offsetX
        let centerY = rect.midY + rect.height * offsetY
        let radius = rect.width * 0.3 * scale

        // Create an organic blob shape using sine waves
        let numPoints = 8
        let points = (0..<numPoints).map { i -> CGPoint in
            let angle = CGFloat(i) / CGFloat(numPoints) * 2 * .pi + phase
            let variation = 0.3 + 0.2 * sin(angle * 3 + phase)
            let distance = radius * (0.8 + variation * 0.4)

            let x = centerX + distance * cos(angle)
            let y = centerY + distance * sin(angle)

            return CGPoint(x: x, y: y)
        }

        if let first = points.first {
            path.move(to: first)
            for i in 1..<points.count {
                let control1 = CGPoint(
                    x: points[i - 1].x + (points[i].x - points[i - 1].x) * 0.33,
                    y: points[i - 1].y + (points[i].y - points[i - 1].y) * 0.33
                )
                let control2 = CGPoint(
                    x: points[i].x - (points[i].x - points[i - 1].x) * 0.33,
                    y: points[i].y - (points[i].y - points[i - 1].y) * 0.33
                )
                path.addCurve(to: points[i], control1: control1, control2: control2)
            }

            // Close path back to start
            let control1 = CGPoint(
                x: points.last!.x + (first.x - points.last!.x) * 0.33,
                y: points.last!.y + (first.y - points.last!.y) * 0.33
            )
            let control2 = CGPoint(
                x: first.x - (first.x - points.last!.x) * 0.33,
                y: first.y - (first.y - points.last!.y) * 0.33
            )
            path.addCurve(to: first, control1: control1, control2: control2)
        }

        return path
    }
}

#Preview {
    AnimatedRainbowBackground()
}
