import SwiftUI

enum GlassStyle {
    case regular
    case clear
    case interactive
}

extension View {
    /// Applies Liquid Glass on iOS 26+, ultraThinMaterial on earlier OS.
    @ViewBuilder
    func adaptiveGlass(_ style: GlassStyle = .regular) -> some View {
        adaptiveGlass(style, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    func adaptiveGlass<S: Shape>(_ style: GlassStyle = .regular, shape: S) -> some View {
        if #available(iOS 26, *) {
            switch style {
            case .regular:
                self.glassEffect(.regular, in: shape)
            case .clear:
                self.glassEffect(.regular.tint(.clear), in: shape)
            case .interactive:
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func adaptiveGlassCapsule(_ style: GlassStyle = .regular) -> some View {
        adaptiveGlass(style, shape: Capsule())
    }
}
