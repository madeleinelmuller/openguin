import SwiftUI

/// Full-screen animated rainbow blob background.
/// Seven luminous, blurred ellipses at the bottom of the screen drift
/// with independent sinusoidal motion, creating a living glow.
struct RainbowBlobsBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            RainbowBlobsLayer(time: context.date.timeIntervalSinceReferenceDate)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Blob Layer

private struct RainbowBlobsLayer: View {
    let time: Double

    private struct BlobSpec {
        let color: Color
        let width: CGFloat
        let height: CGFloat
        /// Horizontal base position as a fraction of screen width
        let xFraction: CGFloat
        /// Vertical base position as a fraction of screen height
        let yFraction: CGFloat
        /// Horizontal oscillation amplitude in points
        let xAmplitude: CGFloat
        /// Vertical oscillation amplitude in points
        let yAmplitude: CGFloat
        let speed: Double
        let phase: Double
    }

    // Seven rainbow blobs — each sits near the bottom with its own drift speed/phase
    private let blobs: [BlobSpec] = [
        BlobSpec(color: .red,    width: 360, height: 360, xFraction: 0.05, yFraction: 0.74, xAmplitude: 48, yAmplitude: 36, speed: 0.47, phase: 0.00),
        BlobSpec(color: .orange, width: 330, height: 320, xFraction: 0.23, yFraction: 0.79, xAmplitude: 40, yAmplitude: 42, speed: 0.60, phase: 1.05),
        BlobSpec(color: .yellow, width: 320, height: 300, xFraction: 0.41, yFraction: 0.75, xAmplitude: 44, yAmplitude: 32, speed: 0.52, phase: 2.10),
        BlobSpec(color: .green,  width: 350, height: 335, xFraction: 0.58, yFraction: 0.81, xAmplitude: 38, yAmplitude: 38, speed: 0.67, phase: 3.15),
        BlobSpec(color: .cyan,   width: 325, height: 300, xFraction: 0.74, yFraction: 0.76, xAmplitude: 42, yAmplitude: 34, speed: 0.55, phase: 4.20),
        BlobSpec(color: .blue,   width: 345, height: 320, xFraction: 0.90, yFraction: 0.83, xAmplitude: 34, yAmplitude: 44, speed: 0.43, phase: 5.25),
        BlobSpec(color: .purple, width: 390, height: 380, xFraction: 0.50, yFraction: 0.88, xAmplitude: 54, yAmplitude: 28, speed: 0.71, phase: 0.78),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // All blobs rendered together then heavily blurred
                ZStack {
                    ForEach(blobs.indices, id: \.self) { i in
                        let blob = blobs[i]
                        let x = geo.size.width * blob.xFraction
                            + sin(time * blob.speed + blob.phase) * Double(blob.xAmplitude)
                        let y = geo.size.height * blob.yFraction
                            + cos(time * blob.speed * 0.73 + blob.phase) * Double(blob.yAmplitude)

                        Ellipse()
                            .fill(blob.color.opacity(0.95))
                            .frame(width: blob.width, height: blob.height)
                            .position(x: x, y: y)
                    }
                }
                // Heavy gaussian blur turns hard-edged blobs into soft glowing light
                .blur(radius: 95)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.05), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .blendMode(.screen)
            }
        }
    }
}

#Preview {
    RainbowBlobsBackground()
        .background(.black)
}
