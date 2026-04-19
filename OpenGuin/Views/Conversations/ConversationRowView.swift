import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let isSelected: Bool

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .primary)
                    .lineLimit(1)

                Text(conversation.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(Self.dateFormatter.localizedString(for: conversation.updatedAt, relativeTo: .now))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
