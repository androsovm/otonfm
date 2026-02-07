import Foundation
import UserNotifications
import FirebaseMessaging
import UIKit

/// Production notification service using UNUserNotificationCenter and Firebase Messaging.
final class NotificationService: NotificationServiceProtocol {

    // MARK: - Properties

    private(set) var isPermissionGranted: Bool = false

    // MARK: - Init

    init() {
        Task { [weak self] in
            await self?.refreshPermissionStatus()
        }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isPermissionGranted = granted

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                await subscribeToTopic("all_users")
            }

            return granted
        } catch {
            isPermissionGranted = false
            return false
        }
    }

    // MARK: - Topics

    func subscribeToTopic(_ topic: String) async {
        do {
            try await Messaging.messaging().subscribe(toTopic: topic)
        } catch {
            // Subscription failed silently; will retry on next token refresh
        }
    }

    // MARK: - Private

    private func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isPermissionGranted = settings.authorizationStatus == .authorized
    }
}
