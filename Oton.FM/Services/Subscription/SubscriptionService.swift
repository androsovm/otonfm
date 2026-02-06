import Foundation
import RevenueCat
import os

private let log = Logger(subsystem: "fm.oton", category: "Subscription")

/// Production subscription service wrapping RevenueCat.
final class SubscriptionService: SubscriptionServiceProtocol {

    private(set) var isPremium: Bool = false

    private enum Keys {
        static let firstLaunchDate = "firstLaunchDate"
        static let lastPaywallDisplayDate = "lastPaywallDisplayDate"
        static let paywallTestMode = "paywallTestMode"
    }

    var isTestModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.paywallTestMode)
    }

    init() {
        registerFirstLaunchIfNeeded()
    }

    func checkPremiumStatus() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasPremium = !customerInfo.entitlements.all.isEmpty
            isPremium = hasPremium
            return hasPremium
        } catch {
            log.error("failed to fetch customer info: \(error.localizedDescription)")
            return false
        }
    }

    func shouldShowPaywall() -> Bool {
        if isTestModeEnabled { return true }
        if isPremium { return false }

        guard let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            return false
        }

        let daysSinceFirstLaunch = Calendar.current.dateComponents(
            [.day], from: firstLaunch, to: Date()
        ).day ?? 0

        guard Constants.Paywall.targetDays.contains(daysSinceFirstLaunch) else { return false }

        // Max once per day
        if let lastShown = UserDefaults.standard.object(forKey: Keys.lastPaywallDisplayDate) as? Date,
           Calendar.current.isDateInToday(lastShown) {
            return false
        }

        return true
    }

    func markPaywallDisplayed() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastPaywallDisplayDate)
    }

    func setTestMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.paywallTestMode)
    }

    // MARK: - Private

    private func registerFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: Keys.firstLaunchDate) == nil {
            UserDefaults.standard.set(Date(), forKey: Keys.firstLaunchDate)
        }
    }
}

/// Stub for compilation before Task #11.
final class StubSubscriptionService: SubscriptionServiceProtocol {
    var isPremium: Bool = false
    var isTestModeEnabled: Bool = false
    func checkPremiumStatus() async -> Bool { false }
    func shouldShowPaywall() -> Bool { false }
    func markPaywallDisplayed() {}
    func setTestMode(_ enabled: Bool) {}
}
