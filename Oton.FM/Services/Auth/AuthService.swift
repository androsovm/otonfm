import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Production auth service using Firebase Authentication.
/// Supports anonymous sign-in and Apple Sign-In linking.
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

    var isAnonymous: Bool {
        guard let user = Auth.auth().currentUser else { return true }
        return !user.providerData.contains { $0.providerID == "apple.com" }
    }

    var canWrite: Bool {
        !isAnonymous && isOnboarded
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

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )

        // Try linking anonymous account to Apple credential
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                try await currentUser.link(with: credential)
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Apple account already exists — sign in directly
                try await Auth.auth().signIn(with: credential)
            }
        } else {
            try await Auth.auth().signIn(with: credential)
        }

        // Pre-fill display name from Apple if provided
        if let givenName = fullName?.givenName, !givenName.isEmpty {
            let current = UserDefaults.standard.string(forKey: Keys.displayName) ?? ""
            if current.isEmpty {
                UserDefaults.standard.set(givenName, forKey: Keys.displayName)
            }
        }
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
