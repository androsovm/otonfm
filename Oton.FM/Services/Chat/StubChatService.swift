import SwiftUI

/// Mock chat service with realistic Yakut diaspora chat data.
/// Simulates new messages arriving every 3-5 seconds via AsyncStream.
final class StubChatService: ChatServiceProtocol {

    // MARK: - Streams

    let messageStream: AsyncStream<ChatMessage>
    let adminStatusStream: AsyncStream<AdminStatus?>

    private var messageContinuation: AsyncStream<ChatMessage>.Continuation?
    private var adminStatusContinuation: AsyncStream<AdminStatus?>.Continuation?

    // MARK: - State

    private(set) var currentAdminStatus: AdminStatus?
    private var messageTimer: Task<Void, Never>?

    // MARK: - Mock data

    private let mockUsers: [ChatUser] = [
        ChatUser(
            displayName: "Айсен",
            countryFlag: "\u{1F1F7}\u{1F1FA}",
            isAdmin: true,
            nameColor: Color(UIColor(red: 0.95, green: 0.48, blue: 0.22, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Сардана",
            countryFlag: "\u{1F1F7}\u{1F1FA}",
            isPremium: true,
            nameColor: Color(UIColor(red: 0.85, green: 0.65, blue: 0.85, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Туйаара",
            countryFlag: "\u{1F1E9}\u{1F1EA}",
            nameColor: Color(UIColor(red: 0.50, green: 0.68, blue: 0.85, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Кюннэй",
            countryFlag: "\u{1F1F0}\u{1F1F7}",
            isPremium: true,
            nameColor: Color(UIColor(red: 0.95, green: 0.52, blue: 0.20, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Нюргун",
            countryFlag: "\u{1F1FA}\u{1F1F8}",
            nameColor: Color(UIColor(red: 0.20, green: 0.80, blue: 0.90, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Саргылана",
            countryFlag: "\u{1F1F7}\u{1F1FA}",
            nameColor: Color(UIColor(red: 0.85, green: 0.60, blue: 0.30, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Дьулустан",
            countryFlag: "\u{1F1F7}\u{1F1FA}",
            nameColor: Color(UIColor(red: 0.10, green: 0.75, blue: 0.45, alpha: 1.0))
        ),
        ChatUser(
            displayName: "Намыына",
            countryFlag: "\u{1F1E9}\u{1F1EA}",
            isPremium: true,
            nameColor: Color(UIColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1.0))
        ),
    ]

    private let mockMessages: [(String, ChatMessageType, String?, String?)] = [
        ("Доброе утро всем! Слушаю из Якутска", .userMessage, nil, nil),
        ("Привет из Берлина! Скучаю по дому", .userMessage, nil, nil),
        ("Кытыл", .songRequest, "Кытыл", "Чахаан"),
        ("Какой красивый голос у этой певицы", .userMessage, nil, nil),
        ("Кыыс Амма", .songRequest, "Кыыс Амма", "Айыы Уола"),
        ("Привет из Сеула! Якутская музыка - лучшая!", .userMessage, nil, nil),
        ("Кто знает когда будет прямой эфир?", .userMessage, nil, nil),
        ("Вечер добрый из Нью-Йорка!", .userMessage, nil, nil),
        ("Эту песню мне бабушка пела", .userMessage, nil, nil),
        ("Куннэйим", .songRequest, "Куннэйим", "Чолбон"),
        ("Слушаю каждый день по дороге на работу", .userMessage, nil, nil),
        ("Барахсан, привет из Москвы!", .userMessage, nil, nil),
        ("Сахалыы ырыалар - туох да сатаммат!", .userMessage, nil, nil),
        ("Мин Ситим", .songRequest, "Мин Ситим", "Ай-Тал"),
        ("Добрый вечер, земляки!", .userMessage, nil, nil),
        ("Ырыаны тыынабын!", .userMessage, nil, nil),
    ]

    // MARK: - Init

    init() {
        var mc: AsyncStream<ChatMessage>.Continuation!
        messageStream = AsyncStream { mc = $0 }

        var ac: AsyncStream<AdminStatus?>.Continuation!
        adminStatusStream = AsyncStream { ac = $0 }

        messageContinuation = mc
        adminStatusContinuation = ac

        currentAdminStatus = AdminStatus(
            text: "12.04 в 18:00 — прямой эфир с Чолбон!",
            type: .normal
        )

        startSimulation()
    }

    deinit {
        messageTimer?.cancel()
        messageContinuation?.finish()
        adminStatusContinuation?.finish()
    }

    // MARK: - ChatServiceProtocol

    func sendMessage(_ text: String) async {
        let message = ChatMessage(
            author: ChatUser(displayName: "Я", countryFlag: "\u{1F1F7}\u{1F1FA}"),
            text: text,
            type: .userMessage
        )
        messageContinuation?.yield(message)
    }

    func sendSongRequest(title: String, artist: String) async {
        let message = ChatMessage(
            author: ChatUser(displayName: "Я", countryFlag: "\u{1F1F7}\u{1F1FA}"),
            text: title,
            type: .songRequest,
            songTitle: title,
            songArtist: artist
        )
        messageContinuation?.yield(message)
    }

    func fetchRecentMessages() async -> [ChatMessage] {
        let now = Date()
        var messages: [ChatMessage] = []

        // Pinned admin announcement
        let admin = mockUsers[0]
        messages.append(ChatMessage(
            author: admin,
            text: "Дорогие слушатели! Добро пожаловать в чат Oton FM!",
            timestamp: now.addingTimeInterval(-3600),
            type: .adminAnnouncement,
            isPinned: true
        ))

        // System message
        messages.append(ChatMessage(
            text: "Сейчас играет: Чолбон — Эн миэхэ",
            timestamp: now.addingTimeInterval(-120),
            type: .system
        ))

        // Recent chat messages
        let recentCount = min(8, mockMessages.count)
        for i in 0..<recentCount {
            let (text, type, songTitle, songArtist) = mockMessages[i]
            let user = mockUsers[i % mockUsers.count]
            let timeOffset = TimeInterval(-600 + i * 70)
            messages.append(ChatMessage(
                author: user,
                text: text,
                timestamp: now.addingTimeInterval(timeOffset),
                type: type,
                songTitle: songTitle,
                songArtist: songArtist
            ))
        }

        return messages
    }

    // MARK: - Simulation

    private func startSimulation() {
        var messageIndex = 8

        messageTimer = Task { [weak self] in
            while !Task.isCancelled {
                let delay = UInt64.random(in: 3_000_000_000...5_000_000_000)
                try? await Task.sleep(nanoseconds: delay)

                guard let self, !Task.isCancelled else { return }

                let (text, type, songTitle, songArtist) = self.mockMessages[messageIndex % self.mockMessages.count]
                let user = self.mockUsers[messageIndex % self.mockUsers.count]

                let message = ChatMessage(
                    author: user,
                    text: text,
                    type: type,
                    songTitle: songTitle,
                    songArtist: songArtist
                )

                self.messageContinuation?.yield(message)
                messageIndex += 1
            }
        }
    }
}
