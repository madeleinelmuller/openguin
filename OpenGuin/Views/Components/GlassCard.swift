import SwiftUI

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    GlassCard {
        Text("Hello, Openguin")
            .font(.headline)
    }
    .padding()
}
