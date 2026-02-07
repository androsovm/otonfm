import Foundation

/// Urgency level for admin status messages.
enum AdminStatusType {
    case normal
    case urgent
}

/// An admin status message shown as a banner on the main screen.
struct AdminStatus: Identifiable {
    let id: UUID
    let text: String
    let type: AdminStatusType
    let timestamp: Date

    init(
        id: UUID = UUID(),
        text: String,
        type: AdminStatusType = .normal,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}
