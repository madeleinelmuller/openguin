import SwiftUI

struct ThinkingBubbleView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            LoadingPenguin(size: 28)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == i ? 1.4 : 0.8)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.18),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation { phase = 0 }
            Timer.scheduledTimer(withTimeInterval: 0.54, repeats: true) { _ in
                Task { @MainActor in
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

#Preview {
    ThinkingBubbleView()
        .padding()
}
