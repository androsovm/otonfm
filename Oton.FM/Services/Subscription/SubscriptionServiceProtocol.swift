import Foundation

/// Wraps RevenueCat for premium status checks and paywall display logic.
protocol SubscriptionServiceProtocol {
    /// Whether the current user has an active premium entitlement.
    var isPremium: Bool { get }

    /// Check premium status asynchronously (network call to RevenueCat).
    func checkPremiumStatus() async -> Bool

    /// Whether the paywall should be auto-shown based on target days and daily limit.
    func shouldShowPaywall() -> Bool

    /// Record that the paywall was displayed today.
    func markPaywallDisplayed()

    /// Whether paywall test mode is enabled (always shows paywall).
    var isTestModeEnabled: Bool { get }

    /// Enable or disable paywall test mode.
    func setTestMode(_ enabled: Bool)
}
