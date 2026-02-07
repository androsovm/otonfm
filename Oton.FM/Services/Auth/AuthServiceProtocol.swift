import Foundation

/// Manages anonymous authentication and user profile data.
protocol AuthServiceProtocol {
    /// Firebase UID of the current user, nil if not signed in.
    var currentUserId: String? { get }

    /// Whether the user has completed onboarding (has a display name).
    var isOnboarded: Bool { get }

    /// User's display name from local storage.
    var displayName: String { get }

    /// User's country flag emoji from local storage.
    var countryFlag: String { get }

    /// Sign in anonymously via Firebase Auth. Returns the user ID.
    func signInAnonymously() async throws -> String

    /// Save profile to UserDefaults and Firestore.
    func saveProfile(displayName: String, countryFlag: String) async throws
}
