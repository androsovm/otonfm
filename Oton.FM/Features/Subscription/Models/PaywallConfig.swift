import Foundation

/// Configuration for paywall display logic.
enum PaywallConfig {
    /// Days after first launch when paywall should auto-show.
    static let targetDays = Constants.Paywall.targetDays
    /// Delay before checking paywall eligibility.
    static let checkDelay = Constants.Paywall.checkDelay
    /// Window to detect recent purchase after paywall dismiss.
    static let purchaseDetectionWindow = Constants.Paywall.purchaseDetectionWindow
}
