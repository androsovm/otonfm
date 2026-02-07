import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Production auth service using Firebase Anonymous Authentication.
/// Stores profile locally in UserDefaults and syncs to Firestore.
final class AuthService: AuthServiceProtocol {

    // MARK: - UserDefaults keys

    private enum Keys {
        static let displayName = "auth_displayName"
        static let countryFlag = "auth_countryFlag"
    }

    // MARK: - Properties

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var isOnboarded: Bool {
        !displayName.isEmpty
    }

    var displayName: String {
        UserDefaults.standard.string(forKey: Keys.displayName) ?? ""
    }

    var countryFlag: String {
        UserDefaults.standard.string(forKey: Keys.countryFlag) ?? ""
    }

    private lazy var db = Firestore.firestore()

    // MARK: - Auth

    @discardableResult
    func signInAnonymously() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    // MARK: - Profile

    func saveProfile(displayName: String, countryFlag: String) async throws {
        UserDefaults.standard.set(displayName, forKey: Keys.displayName)
        UserDefaults.standard.set(countryFlag, forKey: Keys.countryFlag)

        guard let uid = currentUserId else { return }

        try await db.collection("users").document(uid).setData([
            "displayName": displayName,
            "countryFlag": countryFlag,
            "isAdmin": false,
            "isPremium": false,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
