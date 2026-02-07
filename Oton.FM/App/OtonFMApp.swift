import SwiftUI
import RevenueCat
import FirebaseCore
import FirebaseMessaging
import UserNotifications

/// Main entry point for Oton.FM v2.
/// Requires iOS 17+ for @Observable support.
@main
struct OtonFMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var environment = AppEnvironment()
    @State private var isSplashActive = true
    @AppStorage("hasSeenNotificationWelcome") private var hasSeenNotificationWelcome = false

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
            } else if !hasSeenNotificationWelcome {
                WelcomeNotificationView(
                    notificationService: environment.notificationService,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenNotificationWelcome = true
                        }
                    }
                )
            } else {
                PlayerView(
                    viewModel: PlayerViewModel(
                        audioEngine: environment.audioEngine,
                        metadataService: environment.metadataService,
                        artworkService: environment.artworkService,
                        nowPlayingService: environment.nowPlayingService,
                        hapticService: environment.hapticService
                    ),
                    subscriptionVM: SubscriptionViewModel(
                        subscriptionService: environment.subscriptionService,
                        hapticService: environment.hapticService
                    ),
                    chatViewModel: ChatViewModel(
                        chatService: environment.chatService,
                        authService: environment.authService
                    )
                )
            }
        }
    }
}

/// Handles app lifecycle events: Firebase, RevenueCat, FCM push notifications.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)

        // Push notification delegates (permission requested via NotificationService)
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        return true
    }

    // MARK: - APNs token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.subscribe(toTopic: "all_users")
    }

    // MARK: - Foreground notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
