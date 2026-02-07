import Foundation

/// Manages push notification permissions and FCM topic subscriptions.
protocol NotificationServiceProtocol {
    /// Whether the user has granted notification permission.
    var isPermissionGranted: Bool { get }

    /// Request notification permission from the user.
    /// Returns true if permission was granted.
    func requestPermission() async -> Bool

    /// Subscribe to an FCM topic for targeted push notifications.
    func subscribeToTopic(_ topic: String) async
}
