import SwiftUI
import RevenueCat

/// Main entry point for Oton.FM v2.
/// Requires iOS 17+ for @Observable support.
@main
struct OtonFMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var environment = AppEnvironment()
    @State private var isSplashActive = true

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
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
                    )
                )
            }
        }
    }
}

/// Handles app lifecycle events: RevenueCat initialization, first-launch date tracking.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        return true
    }
}
