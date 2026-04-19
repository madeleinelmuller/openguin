import SwiftUI

struct HapticButton<Label: View>: View {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.style = style
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            action()
        } label: {
            label()
        }
    }
}
