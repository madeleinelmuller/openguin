import SwiftUI

struct RainbowBlobsBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            AuroraLayer(time: context.date.timeIntervalSinceReferenceDate)
        }
        .ignoresSafeArea()
    }
}

private struct AuroraLayer: View {
    let time: Double

    private struct BlobSpec {
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let xFraction: CGFloat
        let yFraction: CGFloat
        let xAmp: CGFloat
        let yAmp: CGFloat
        let speed: Double
        let phase: Double
        let opacity: Double
    }

    // Full rainbow spectrum with all colors evenly distributed
    // yFraction ≥ 1.0 places the blob center at/below the screen bottom,
    // so the gradient peak is at the screen edge and dims going upward.
    private let blobs: [BlobSpec] = [
        // Red
        BlobSpec(color: Color(red: 1.000, green: 0.000, blue: 0.000), width: 220, height: 900, xFraction: 0.05, yFraction: 1.00, xAmp: 35, yAmp: 12, speed: 0.19, phase: 0.0, opacity: 0.78),
        // Orange
        BlobSpec(color: Color(red: 1.000, green: 0.500, blue: 0.000), width: 240, height: 920, xFraction: 0.18, yFraction: 1.00, xAmp: 42, yAmp: 14, speed: 0.20, phase: 0.9, opacity: 0.88),
        // Yellow
        BlobSpec(color: Color(red: 1.000, green: 1.000, blue: 0.000), width: 235, height: 910, xFraction: 0.31, yFraction: 1.00, xAmp: 38, yAmp: 13, speed: 0.18, phase: 1.8, opacity: 0.82),
        // Lime
        BlobSpec(color: Color(red: 0.500, green: 1.000, blue: 0.000), width: 205, height: 870, xFraction: 0.44, yFraction: 1.00, xAmp: 36, yAmp: 11, speed: 0.21, phase: 2.7, opacity: 0.72),
        // Green
        BlobSpec(color: Color(red: 0.000, green: 1.000, blue: 0.000), width: 215, height: 880, xFraction: 0.57, yFraction: 1.00, xAmp: 40, yAmp: 13, speed: 0.17, phase: 3.6, opacity: 0.68),
        // Cyan
        BlobSpec(color: Color(red: 0.000, green: 1.000, blue: 1.000), width: 225, height: 895, xFraction: 0.70, yFraction: 1.00, xAmp: 34, yAmp: 12, speed: 0.22, phase: 4.5, opacity: 0.75),
        // Blue
        BlobSpec(color: Color(red: 0.000, green: 0.000, blue: 1.000), width: 210, height: 875, xFraction: 0.83, yFraction: 1.00, xAmp: 38, yAmp: 13, speed: 0.19, phase: 5.4, opacity: 0.80),
        // Indigo
        BlobSpec(color: Color(red: 0.290, green: 0.000, blue: 0.510), width: 200, height: 860, xFraction: 0.96, yFraction: 1.00, xAmp: 32, yAmp: 11, speed: 0.20, phase: 6.3, opacity: 0.70),
        // Violet
        BlobSpec(color: Color(red: 0.933, green: 0.510, blue: 0.933), width: 190, height: 850, xFraction: 0.11, yFraction: 1.00, xAmp: 36, yAmp: 12, speed: 0.18, phase: 1.2, opacity: 0.65),
        // Magenta
        BlobSpec(color: Color(red: 1.000, green: 0.000, blue: 1.000), width: 215, height: 880, xFraction: 0.25, yFraction: 1.00, xAmp: 39, yAmp: 13, speed: 0.21, phase: 2.4, opacity: 0.76),
        // Pink
        BlobSpec(color: Color(red: 1.000, green: 0.753, blue: 0.796), width: 205, height: 870, xFraction: 0.39, yFraction: 1.00, xAmp: 35, yAmp: 11, speed: 0.19, phase: 3.6, opacity: 0.62),
        // Teal
        BlobSpec(color: Color(red: 0.000, green: 0.502, blue: 0.502), width: 200, height: 860, xFraction: 0.53, yFraction: 1.00, xAmp: 37, yAmp: 12, speed: 0.20, phase: 4.8, opacity: 0.64),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.04, green: 0.03, blue: 0.04)

                ZStack {
                    ForEach(blobs.indices, id: \.self) { i in
                        let b = blobs[i]
                        let x = geo.size.width  * b.xFraction + sin(time * b.speed + b.phase) * b.xAmp
                        let y = geo.size.height * b.yFraction + cos(time * b.speed * 0.6 + b.phase) * b.yAmp

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        b.color.opacity(0.0),
                                        b.color.opacity(b.opacity)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: b.width, height: b.height)
                            .rotationEffect(.degrees(sin(time * b.speed + b.phase) * 5))
                            .position(x: x, y: y)
                            .blendMode(.screen)
                    }
                }
                .drawingGroup()
                .blur(radius: 110)
                // Fully present at bottom 2/3, gone by top third
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear,              location: 0.00),
                            .init(color: .clear,              location: 0.22),
                            .init(color: .black.opacity(0.55), location: 0.38),
                            .init(color: .black,              location: 0.52),
                            .init(color: .black,              location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

#Preview {
    RainbowBlobsBackground()
}
