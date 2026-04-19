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
        self.background(.ultraThinMaterial, in: shape)
    }

    @ViewBuilder
    func adaptiveGlassCapsule(_ style: GlassStyle = .regular) -> some View {
        adaptiveGlass(style, shape: Capsule())
    }
}
