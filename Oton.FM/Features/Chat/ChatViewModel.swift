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
    var showOnboarding: Bool = false

    // MARK: - Dependencies

    private let chatService: any ChatServiceProtocol
    let authServiceForOnboarding: any AuthServiceProtocol
    private var authService: any AuthServiceProtocol { authServiceForOnboarding }

    // MARK: - Internal state

    private var messageTask: Task<Void, Never>?
    private var adminStatusTask: Task<Void, Never>?
    private var pendingAction: PendingAction?
    private var lastSentAt: Date = .distantPast
    private let cooldown: TimeInterval = 10.0
    var cooldownRemaining: TimeInterval = 0

    private enum PendingAction {
        case message(String)
        case songRequest(title: String, artist: String)
    }

    // MARK: - Init

    init(chatService: any ChatServiceProtocol, authService: any AuthServiceProtocol) {
        self.chatService = chatService
        self.authServiceForOnboarding = authService
        self.adminStatus = chatService.currentAdminStatus
    }

    // MARK: - Lifecycle

    /// Start observing chat streams. Call from .onAppear / .task.
    func startObserving() {
        // Sign in silently in background
        Task {
            _ = try? await authService.signInAnonymously()
        }

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

    var isCoolingDown: Bool {
        cooldownRemaining > 0
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if !authService.isOnboarded {
            pendingAction = .message(text)
            inputText = ""
            showOnboarding = true
            return
        }

        guard checkCooldown() else { return }

        inputText = ""
        Task {
            await chatService.sendMessage(text)
        }
    }

    func sendSongRequest(title: String, artist: String) {
        if !authService.isOnboarded {
            pendingAction = .songRequest(title: title, artist: artist)
            showOnboarding = true
            return
        }

        guard checkCooldown() else { return }

        Task {
            await chatService.sendSongRequest(title: title, artist: artist)
        }
    }

    private func checkCooldown() -> Bool {
        let elapsed = Date().timeIntervalSince(lastSentAt)
        if elapsed < cooldown {
            cooldownRemaining = cooldown - elapsed
            startCooldownTimer()
            return false
        }
        lastSentAt = Date()
        return true
    }

    private func startCooldownTimer() {
        Task { @MainActor in
            while cooldownRemaining > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                let elapsed = Date().timeIntervalSince(lastSentAt)
                cooldownRemaining = max(0, cooldown - elapsed)
            }
        }
    }

    /// Called after onboarding completes. Sends pending message if any.
    func onboardingCompleted() {
        showOnboarding = false
        guard let action = pendingAction else { return }
        pendingAction = nil

        Task {
            switch action {
            case .message(let text):
                await chatService.sendMessage(text)
            case .songRequest(let title, let artist):
                await chatService.sendSongRequest(title: title, artist: artist)
            }
        }
    }

    func markAsRead() {
        unreadCount = 0
    }
}
