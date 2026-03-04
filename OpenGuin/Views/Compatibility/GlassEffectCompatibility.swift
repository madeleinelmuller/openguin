import SwiftUI

/// Compatibility shim for projects built with SDKs that do not yet include Apple's glass effect APIs.
///
/// This preserves source compatibility for `GlassEffectContainer`, `.glassEffect`, and `.glassEffectID`.
struct GlassEffectContainer<Content: View>: View {
    private let content: Content

    init(spacing _: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}

struct GlassEffect {
    fileprivate var tintColor: Color?
    fileprivate var isInteractive = false

    static var regular: GlassEffect {
        GlassEffect()
    }

    func tint(_ color: Color) -> GlassEffect {
        var copy = self
        copy.tintColor = color
        return copy
    }

    func interactive() -> GlassEffect {
        var copy = self
        copy.isInteractive = true
        return copy
    }
}

private struct ErasedShape: InsettableShape {
    nonisolated(unsafe) private let pathBuilder: (CGRect) -> Path
    private var insetAmount: CGFloat = 0

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    private init(pathBuilder: @escaping (CGRect) -> Path, insetAmount: CGFloat) {
        self.pathBuilder = pathBuilder
        self.insetAmount = insetAmount
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect.insetBy(dx: insetAmount, dy: insetAmount))
    }

    func inset(by amount: CGFloat) -> ErasedShape {
        ErasedShape(pathBuilder: pathBuilder, insetAmount: insetAmount + amount)
    }
}

extension View {
    func glassEffect<S: Shape>(_ effect: GlassEffect = GlassEffect.regular, in shape: S) -> some View {
        let resolvedTint = effect.tintColor ?? Color.white.opacity(0.12)

        return self
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                ErasedShape(shape)
                    .strokeBorder(Color.white.opacity(effect.isInteractive ? 0.3 : 0.18), lineWidth: effect.isInteractive ? 1.2 : 1)
                    .allowsHitTesting(false)
            }
            .overlay {
                ErasedShape(shape)
                    .fill(resolvedTint.opacity(effect.isInteractive ? 0.16 : 0.1))
                    .allowsHitTesting(false)
            }
    }

    func glassEffectID(_ id: String, in _: Namespace.ID) -> some View {
        accessibilityIdentifier(id)
    }
}
