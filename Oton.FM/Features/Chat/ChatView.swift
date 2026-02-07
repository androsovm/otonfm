import SwiftUI

/// Main chat view presented as a sheet/bottom drawer.
/// Contains header with drag indicator, pinned announcement,
/// scrollable messages, and input bar.
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator + header
            chatHeader

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Pinned announcement
            if let pinned = viewModel.pinnedAnnouncement {
                pinnedAnnouncementView(pinned)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Input bar
            ChatInputBar(text: $viewModel.inputText, onSend: viewModel.sendMessage)
        }
        .background(.clear)
        .onAppear {
            viewModel.isChatOpen = true
            viewModel.markAsRead()
        }
        .onDisappear {
            viewModel.isChatOpen = false
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        VStack(spacing: 8) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(
                    width: Constants.Chat.dragIndicatorWidth,
                    height: Constants.Chat.dragIndicatorHeight
                )
                .padding(.top, 10)

            HStack {
                Text("Эфир")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(viewModel.messages.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )

                Spacer()
            }
            .padding(.horizontal, Constants.Chat.messageHorizontalPadding)
            .padding(.bottom, 8)
        }
        .frame(height: Constants.Chat.headerHeight)
    }

    // MARK: - Pinned Announcement

    @ViewBuilder
    private func pinnedAnnouncementView(_ message: ChatMessage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accentPrimary)

            Image("otonLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text(message.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.accentPrimary.opacity(0.08))
    }
}
