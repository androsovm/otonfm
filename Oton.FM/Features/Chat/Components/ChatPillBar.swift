import SwiftUI

/// Compact pill bar shown on the main player screen.
/// Displays chat preview and unread badge; tapping opens the chat sheet.
struct ChatPillBar: View {
    let lastMessagePreview: String?
    let unreadCount: Int
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)

                Text(displayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if unreadCount > 0 {
                    Circle()
                        .fill(AppColors.accentPrimary)
                        .frame(
                            width: Constants.Chat.badgeSize,
                            height: Constants.Chat.badgeSize
                        )
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Constants.Chat.pillHeight)
            .frame(width: UIScreen.main.bounds.width * Constants.Chat.pillWidthRatio)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(appeared ? 1.0 : 0.8)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private var displayText: String {
        if let preview = lastMessagePreview, !preview.isEmpty {
            return preview
        }
        return "Чат"
    }
}
