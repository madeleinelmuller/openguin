import SwiftUI

/// Applies a per-word staggered reveal: opacity + blur + Y-offset → visible.
/// Applied to each word in an assistant message bubble.
struct WordRevealModifier: ViewModifier {
    let isRevealed: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .blur(radius: isRevealed ? 0 : 5)
            .offset(y: isRevealed ? 0 : 8)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.72)
                    .delay(delay),
                value: isRevealed
            )
    }
}

extension View {
    func wordReveal(isRevealed: Bool, delay: Double) -> some View {
        modifier(WordRevealModifier(isRevealed: isRevealed, delay: delay))
    }
}

/// Wraps an assistant message string into a flow of animated words.
struct RevealingText: View {
    let text: String
    let isRevealed: Bool

    // Cap stagger to first N words to avoid very long messages animating forever
    private let maxStaggeredWords = 80
    private let delayPerWord = 0.018

    private var words: [String] {
        text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    var body: some View {
        // Custom flow layout using wrapped HStacks inside a VStack
        FlowLayout(spacing: 3) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                Text(word + " ")
                    .wordReveal(
                        isRevealed: isRevealed,
                        delay: isRevealed ? min(Double(idx), Double(maxStaggeredWords)) * delayPerWord : 0
                    )
            }
        }
    }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps items left-to-right.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (subview, frame) in zip(subviews, result.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var frames: [CGRect]
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            frames: frames
        )
    }
}
