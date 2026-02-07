import SwiftUI

/// Type of chat message determining its appearance and behavior.
enum ChatMessageType {
    case userMessage
    case songRequest
    case adminAnnouncement
    case adminStatus
    case system
}

/// A single message in the Oton.FM chat.
struct ChatMessage: Identifiable {
    let id: UUID
    let author: ChatUser?
    let text: String
    let timestamp: Date
    let type: ChatMessageType

    // Song request specific
    var songTitle: String?
    var songArtist: String?

    // Admin specific
    var isPinned: Bool
    var isUrgent: Bool

    init(
        id: UUID = UUID(),
        author: ChatUser? = nil,
        text: String,
        timestamp: Date = Date(),
        type: ChatMessageType,
        songTitle: String? = nil,
        songArtist: String? = nil,
        isPinned: Bool = false,
        isUrgent: Bool = false
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.timestamp = timestamp
        self.type = type
        self.songTitle = songTitle
        self.songArtist = songArtist
        self.isPinned = isPinned
        self.isUrgent = isUrgent
    }
}
