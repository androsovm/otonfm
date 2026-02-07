import SwiftUI

/// Coordinates chat state and exposes UI-ready properties.
@Observable
final class ChatViewModel {

    // MARK: - UI State

    var messages: [ChatMessage] = []
    var adminStatus: AdminStatus?
    var pinnedAnnouncement: ChatMessage?
    var inputText: String = ""
    var unreadCount: Int = 0
    var isChatOpen: Bool = false

    // MARK: - Dependencies

    private let chatService: any ChatServiceProtocol

    // MARK: - Internal state

    private var messageTask: Task<Void, Never>?
    private var adminStatusTask: Task<Void, Never>?

    // MARK: - Init

    init(chatService: any ChatServiceProtocol) {
        self.chatService = chatService
        self.adminStatus = chatService.currentAdminStatus
    }

    // MARK: - Lifecycle

    /// Start observing chat streams. Call from .onAppear / .task.
    func startObserving() {
        Task { @MainActor in
            let recent = await chatService.fetchRecentMessages()
            messages = recent
            pinnedAnnouncement = recent.first { $0.type == .adminAnnouncement && $0.isPinned }
        }

        messageTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await message in self.chatService.messageStream {
                self.messages.append(message)
                if !self.isChatOpen {
                    self.unreadCount += 1
                }
                if message.type == .adminAnnouncement && message.isPinned {
                    self.pinnedAnnouncement = message
                }
            }
        }

        adminStatusTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await status in self.chatService.adminStatusStream {
                self.adminStatus = status
            }
        }
    }

    /// Cancel observation tasks. Call from .onDisappear.
    func stopObserving() {
        messageTask?.cancel()
        adminStatusTask?.cancel()
    }

    // MARK: - Actions

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        Task {
            await chatService.sendMessage(text)
        }
    }

    func sendSongRequest(title: String, artist: String) {
        Task {
            await chatService.sendSongRequest(title: title, artist: artist)
        }
    }

    func markAsRead() {
        unreadCount = 0
    }
}
