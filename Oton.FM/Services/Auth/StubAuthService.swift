import Foundation

/// Mock auth service for previews and tests.
final class StubAuthService: AuthServiceProtocol {
    var currentUserId: String? = "stub-user-id"
    var isOnboarded: Bool = true
    var isAnonymous: Bool = false
    var displayName: String = "Тест"
    var countryFlag: String = "\u{1F1F7}\u{1F1FA}"

    var canWrite: Bool {
        !isAnonymous && isOnboarded
    }

    func signInAnonymously() async throws -> String {
        "stub-user-id"
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        isAnonymous = false
    }

    func saveProfile(displayName: String, countryFlag: String) async throws {
        self.displayName = displayName
        self.countryFlag = countryFlag
        self.isOnboarded = true
    }
}
