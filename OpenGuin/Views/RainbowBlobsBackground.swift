import SwiftUI

/// Full-screen animated rainbow blob background.
/// Seven luminous, blurred ellipses at the bottom of the screen drift
/// with independent sinusoidal motion, creating a living glow.
struct RainbowBlobsBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
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
        BlobSpec(color: .red,    width: 280, height: 200, xFraction: 0.05, yFraction: 0.84, xAmplitude: 40, yAmplitude: 22, speed: 0.47, phase: 0.00),
        BlobSpec(color: .orange, width: 250, height: 180, xFraction: 0.23, yFraction: 0.90, xAmplitude: 32, yAmplitude: 28, speed: 0.60, phase: 1.05),
        BlobSpec(color: .yellow, width: 230, height: 170, xFraction: 0.41, yFraction: 0.86, xAmplitude: 36, yAmplitude: 18, speed: 0.52, phase: 2.10),
        BlobSpec(color: .green,  width: 260, height: 190, xFraction: 0.58, yFraction: 0.92, xAmplitude: 28, yAmplitude: 25, speed: 0.67, phase: 3.15),
        BlobSpec(color: .cyan,   width: 240, height: 175, xFraction: 0.74, yFraction: 0.87, xAmplitude: 34, yAmplitude: 20, speed: 0.55, phase: 4.20),
        BlobSpec(color: .blue,   width: 255, height: 185, xFraction: 0.90, yFraction: 0.94, xAmplitude: 26, yAmplitude: 30, speed: 0.43, phase: 5.25),
        BlobSpec(color: .purple, width: 290, height: 210, xFraction: 0.50, yFraction: 0.98, xAmplitude: 45, yAmplitude: 16, speed: 0.71, phase: 0.78),
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
                            .fill(blob.color.opacity(0.90))
                            .frame(width: blob.width, height: blob.height)
                            .position(x: x, y: y)
                    }
                }
                // Heavy gaussian blur turns hard-edged blobs into soft glowing light
                .blur(radius: 72)
            }
        }
    }
}

#Preview {
    RainbowBlobsBackground()
        .background(.black)
}
