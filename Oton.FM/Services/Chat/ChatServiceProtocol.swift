import Foundation

/// Manages chat messaging, admin announcements, and status updates.
/// Emits new messages through an async stream.
protocol ChatServiceProtocol {
    /// Async stream of incoming chat messages.
    var messageStream: AsyncStream<ChatMessage> { get }

    /// Async stream of admin status updates (for main screen banner).
    var adminStatusStream: AsyncStream<AdminStatus?> { get }

    /// Send a user message to the chat.
    func sendMessage(_ text: String) async

    /// Send a song request to the chat.
    func sendSongRequest(title: String, artist: String) async

    /// Fetch initial batch of recent messages.
    func fetchRecentMessages() async -> [ChatMessage]

    /// Current admin status (if any).
    var currentAdminStatus: AdminStatus? { get }
}
