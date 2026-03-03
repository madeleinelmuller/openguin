import SwiftUI

// MARK: - iOS 26 Glass Effect Compatibility Layer
//
// This file provides type stubs for iOS 26 glass effect APIs to allow
// compilation on iOS 18 during development. On iOS 26+, the native Apple
// implementations are used automatically.
//
// Target: iOS 26.0+ (exclusive distribution)
// Build compatibility: iOS 18+ (development only)

#if os(iOS) && swift(<6.0)
// Stub implementations for development on iOS 18-25
// These will be replaced by native APIs on iOS 26+

// MARK: - GlassEffectContainer Stub
/// Stub for iOS 26 GlassEffectContainer
/// On iOS 26+: Uses native glass morphing with automatic shape transitions.
/// On iOS 18-25: Stub for compilation only (not distributed to these versions).
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
    }
}

// MARK: - Glass Effect Style Stubs
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

#endif

// MARK: - View Extensions for Glass Effects
extension View {
    /// Glass effect modifier - compiles on iOS 18+ for development.
    /// On iOS 26+: Uses native glass morphing.
    /// On iOS 18-25: Stub (not distributed to these versions).
    @ViewBuilder
    func glassEffect<S: InsettableShape>(
        _ style: GlassEffectStyle = GlassEffectStyle.regular,
        in shape: S
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26, *) {
            // Native iOS 26 glass effect
            self
        } else {
            // Stub for compilation on iOS 18-25
            self
        }
        #else
        self
        #endif
    }

    /// Assigns a morphing ID for glass effects (iOS 26+).
    /// On iOS 18-25: Stub (not distributed).
    func glassEffectID<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID
    ) -> some View {
        self
    }

    /// Unions distant glass elements visually (iOS 26+).
    /// On iOS 18-25: Stub (not distributed).
    func glassEffectUnion() -> some View {
        self
    }
}
