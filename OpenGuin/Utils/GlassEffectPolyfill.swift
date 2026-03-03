import SwiftUI

// MARK: - iOS 26 Glass Effect Polyfill
//
// This provides stub implementations for GlassEffectContainer and related
// modifiers to allow the project to compile on iOS 18.
//
// On iOS 26+, these will be replaced by native Apple implementations.
// On iOS 18-25, they provide fallback styling using blur and opacity.

// MARK: - GlassEffectContainer (iOS 26 Feature)
/// A container that applies glass morphing effects to its content.
/// On iOS 26+: Uses native glass morphing with automatic shape transitions.
/// On iOS 18-25: Uses blur + opacity fallback.
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(spacing: spacing ?? 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .blur(radius: 10)
        )
    }
}

// MARK: - Glass Effect Style
struct GlassEffectStyle {
    var baseVariant: GlassVariant = .regular
    var tintColor: Color = .clear
    var isInteractive: Bool = false

    enum GlassVariant {
        case regular
        case clear
        case identity
    }

    static var regular: GlassEffectStyle {
        GlassEffectStyle(baseVariant: .regular)
    }

    func tint(_ color: Color) -> GlassEffectStyle {
        var style = self
        style.tintColor = color
        return style
    }

    func interactive() -> GlassEffectStyle {
        var style = self
        style.isInteractive = true
        return style
    }
}

// MARK: - View Extensions for Glass Effects
extension View {
    /// Applies a glass morphing effect.
    /// - Parameter style: The glass effect style (regular, clear, or identity)
    /// - Parameter shape: The shape container for the effect
    @ViewBuilder
    func glassEffect<S: InsettableShape>(
        _ style: GlassEffectStyle = GlassEffectStyle.regular,
        in shape: S
    ) -> some View {
        let backgroundColor: Color
        let blurRadius: CGFloat
        let opacity: Double

        switch style.baseVariant {
        case .regular:
            backgroundColor = style.tintColor.opacity(0.1)
            blurRadius = 10
            opacity = 0.9
        case .clear:
            backgroundColor = style.tintColor.opacity(0.05)
            blurRadius = 15
            opacity = 0.95
        case .identity:
            backgroundColor = style.tintColor.opacity(0.08)
            blurRadius = 8
            opacity = 0.85
        }

        self
            .background(
                shape
                    .fill(backgroundColor)
                    .blur(radius: blurRadius)
                    .opacity(opacity)
            )
            .foregroundStyle(style.tintColor == .clear ? .primary : .primary)
    }

    /// Assigns a morphing ID for glass effects.
    /// On iOS 26+: Creates a morphing animation between surfaces with the same ID.
    /// On iOS 18-25: No-op (morphing not supported in fallback).
    func glassEffectID<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID
    ) -> some View {
        // iOS 26 feature: morphing between related glass surfaces
        // On older versions, this is a no-op
        self
    }

    /// Unions distant glass elements visually.
    /// On iOS 26+: Creates a visual grouping that morphs together.
    /// On iOS 18-25: No-op.
    func glassEffectUnion() -> some View {
        self
    }
}

// MARK: - Namespace Extension (for glassEffectID)
extension Namespace.ID {
    // Marker for glass effect IDs
}
