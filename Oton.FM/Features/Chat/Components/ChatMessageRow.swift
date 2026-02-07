import SwiftUI

/// A single message row in the chat, styled by message type.
/// Uses flat Twitch-style layout (no bubbles).
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.type {
        case .userMessage:
            userMessageView
        case .songRequest:
            songRequestView
        case .adminAnnouncement:
            adminAnnouncementView
        case .adminStatus:
            adminStatusView
        case .system:
            systemView
        }
    }

    // MARK: - User Message

    private var userMessageView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let author = message.author {
                Text(author.countryFlag)
                    .font(.system(size: 12))
                Text(" ")

                Text(author.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(author.nameColor)

                if author.isPremium {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: Constants.Chat.premiumIconSize))
                        .foregroundStyle(Color(r: 255, g: 215, b: 0))
                        .padding(.leading, 2)
                }

                Text(": ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(author.nameColor)
            }

            Text(message.text)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
        .padding(.vertical, Constants.Chat.messageVerticalPadding)
    }

    // MARK: - Song Request

    private var songRequestView: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColors.accentPrimary)
                .frame(width: Constants.Chat.songRequestBorderWidth)

            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                if let title = message.songTitle {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                if let artist = message.songArtist {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if let author = message.author {
                Text(author.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
        .padding(.vertical, 2)
    }

    // MARK: - Admin Announcement

    private var adminAnnouncementView: some View {
        HStack(spacing: 10) {
            Image("otonLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(message.text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.accentPrimary.opacity(Constants.Chat.adminBgOpacity))
        )
        .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
        .padding(.vertical, 2)
    }

    // MARK: - Admin Status

    private var adminStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.accentPrimary)

            Text(message.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.accentPrimary.opacity(Constants.Chat.adminBgOpacity))
        )
        .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
        .padding(.vertical, 2)
    }

    // MARK: - System

    private var systemView: some View {
        Text(message.text)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
            .padding(.vertical, 6)
    }
}
