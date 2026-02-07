import SwiftUI
import FirebaseFirestore

/// Production chat service backed by Firestore.
/// Listens to `messages` and `admin_status/current` collections in real time.
final class FirebaseChatService: ChatServiceProtocol {

    // MARK: - Streams

    let messageStream: AsyncStream<ChatMessage>
    let adminStatusStream: AsyncStream<AdminStatus?>

    private var messageContinuation: AsyncStream<ChatMessage>.Continuation?
    private var adminStatusContinuation: AsyncStream<AdminStatus?>.Continuation?

    // MARK: - State

    private(set) var currentAdminStatus: AdminStatus?
    private lazy var db = Firestore.firestore()
    private let authService: any AuthServiceProtocol
    private var messageListener: ListenerRegistration?
    private var adminStatusListener: ListenerRegistration?

    // MARK: - Init

    init(authService: any AuthServiceProtocol) {
        self.authService = authService

        var mc: AsyncStream<ChatMessage>.Continuation!
        messageStream = AsyncStream { mc = $0 }

        var ac: AsyncStream<AdminStatus?>.Continuation!
        adminStatusStream = AsyncStream { ac = $0 }

        messageContinuation = mc
        adminStatusContinuation = ac

        // Listeners start lazily on first fetchRecentMessages() call,
        // after FirebaseApp.configure() has completed.
    }

    private var listenersStarted = false

    private func startListenersIfNeeded() {
        guard !listenersStarted else { return }
        listenersStarted = true
        startMessageListener()
        startAdminStatusListener()
    }

    deinit {
        messageListener?.remove()
        adminStatusListener?.remove()
        messageContinuation?.finish()
        adminStatusContinuation?.finish()
    }

    // MARK: - ChatServiceProtocol

    func sendMessage(_ text: String) async {
        guard let uid = authService.currentUserId else { return }

        let userRef = db.collection("users").document(uid)
        try? await userRef.updateData(["lastMessageAt": FieldValue.serverTimestamp()])

        try? await db.collection("messages").addDocument(data: [
            "text": text,
            "type": "userMessage",
            "authorId": uid,
            "authorName": authService.displayName,
            "authorFlag": authService.countryFlag,
            "authorIsAdmin": false,
            "authorIsPremium": false,
            "songTitle": NSNull(),
            "songArtist": NSNull(),
            "isPinned": false,
            "isUrgent": false,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func sendSongRequest(title: String, artist: String) async {
        guard let uid = authService.currentUserId else { return }

        let userRef = db.collection("users").document(uid)
        try? await userRef.updateData(["lastMessageAt": FieldValue.serverTimestamp()])

        try? await db.collection("messages").addDocument(data: [
            "text": title,
            "type": "songRequest",
            "authorId": uid,
            "authorName": authService.displayName,
            "authorFlag": authService.countryFlag,
            "authorIsAdmin": false,
            "authorIsPremium": false,
            "songTitle": title,
            "songArtist": artist,
            "isPinned": false,
            "isUrgent": false,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchRecentMessages() async -> [ChatMessage] {
        startListenersIfNeeded()
        do {
            let snapshot = try await db.collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            return snapshot.documents.reversed().compactMap { parseMessage($0) }
        } catch {
            return []
        }
    }

    // MARK: - Listeners

    private func startMessageListener() {
        let query = db.collection("messages")
            .order(by: "createdAt", descending: false)
            .whereField("createdAt", isGreaterThan: Timestamp(date: Date()))

        messageListener = query.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            for change in snapshot.documentChanges where change.type == .added {
                if let message = self.parseMessage(change.document) {
                    self.messageContinuation?.yield(message)
                }
            }
        }
    }

    private func startAdminStatusListener() {
        adminStatusListener = db.collection("admin_status").document("current")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }

                let isActive = data["isActive"] as? Bool ?? false
                guard isActive else {
                    self.currentAdminStatus = nil
                    self.adminStatusContinuation?.yield(nil)
                    return
                }

                let text = data["text"] as? String ?? ""
                let typeStr = data["type"] as? String ?? "normal"
                let type: AdminStatusType = typeStr == "urgent" ? .urgent : .normal

                let status = AdminStatus(text: text, type: type)
                self.currentAdminStatus = status
                self.adminStatusContinuation?.yield(status)
            }
    }

    // MARK: - Parsing

    private func parseMessage(_ doc: DocumentSnapshot) -> ChatMessage? {
        guard let data = doc.data() else { return nil }

        let text = data["text"] as? String ?? ""
        let typeStr = data["type"] as? String ?? "userMessage"
        let authorName = data["authorName"] as? String ?? ""
        let authorFlag = data["authorFlag"] as? String ?? ""
        let authorIsAdmin = data["authorIsAdmin"] as? Bool ?? false
        let authorIsPremium = data["authorIsPremium"] as? Bool ?? false
        let isPinned = data["isPinned"] as? Bool ?? false
        let isUrgent = data["isUrgent"] as? Bool ?? false
        let songTitle = data["songTitle"] as? String
        let songArtist = data["songArtist"] as? String
        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        let type: ChatMessageType
        switch typeStr {
        case "songRequest": type = .songRequest
        case "adminAnnouncement": type = .adminAnnouncement
        case "system": type = .system
        default: type = .userMessage
        }

        let nameColor = ChatUserColor.color(for: authorName)
        let author = ChatUser(
            displayName: authorName,
            countryFlag: authorFlag,
            isAdmin: authorIsAdmin,
            isPremium: authorIsPremium,
            nameColor: nameColor
        )

        return ChatMessage(
            author: author,
            text: text,
            timestamp: timestamp,
            type: type,
            songTitle: songTitle,
            songArtist: songArtist,
            isPinned: isPinned,
            isUrgent: isUrgent
        )
    }
}
