import Foundation

/// Mock notification service for previews and tests.
final class StubNotificationService: NotificationServiceProtocol {
    var isPermissionGranted: Bool = false

    func requestPermission() async -> Bool {
        isPermissionGranted = true
        return true
    }

    func subscribeToTopic(_ topic: String) async {}
}
