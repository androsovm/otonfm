import SwiftUI

/// A user participating in the Oton.FM chat.
struct ChatUser: Identifiable {
    let id: UUID
    let displayName: String
    let countryFlag: String
    let isAdmin: Bool
    let isPremium: Bool
    let nameColor: Color

    var initials: String {
        String(displayName.prefix(1))
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        countryFlag: String,
        isAdmin: Bool = false,
        isPremium: Bool = false,
        nameColor: Color = .white
    ) {
        self.id = id
        self.displayName = displayName
        self.countryFlag = countryFlag
        self.isAdmin = isAdmin
        self.isPremium = isPremium
        self.nameColor = nameColor
    }
}
