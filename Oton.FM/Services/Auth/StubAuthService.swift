import Foundation

/// Mock auth service for previews and tests.
final class StubAuthService: AuthServiceProtocol {
    var currentUserId: String? = "stub-user-id"
    var isOnboarded: Bool = true
    var displayName: String = "Тест"
    var countryFlag: String = "\u{1F1F7}\u{1F1FA}"

    func signInAnonymously() async throws -> String {
        "stub-user-id"
    }

    func saveProfile(displayName: String, countryFlag: String) async throws {
        self.displayName = displayName
        self.countryFlag = countryFlag
        self.isOnboarded = true
    }
}
