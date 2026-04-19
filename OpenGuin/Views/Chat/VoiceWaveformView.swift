import SwiftUI

struct VoiceWaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: max(4, CGFloat(level) * 40))
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: level)
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    VoiceWaveformView(levels: (0..<30).map { _ in Float.random(in: 0.1...1.0) })
        .padding()
}
