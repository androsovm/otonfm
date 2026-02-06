import SwiftUI

/// Manages paywall presentation and purchase state.
@Observable
final class SubscriptionViewModel {
    var showingPaywall = false
    var showPurchaseSuccess = false
    var isPremium = false

    private let subscriptionService: any SubscriptionServiceProtocol
    private let hapticService: any HapticServiceProtocol

    init(
        subscriptionService: any SubscriptionServiceProtocol,
        hapticService: any HapticServiceProtocol
    ) {
        self.subscriptionService = subscriptionService
        self.hapticService = hapticService
    }

    /// Check if paywall should auto-show and present it.
    func checkAndShowPaywall() {
        Task { @MainActor in
            isPremium = await subscriptionService.checkPremiumStatus()

            try? await Task.sleep(nanoseconds: UInt64(Constants.Paywall.checkDelay * 1_000_000_000))

            if !isPremium && subscriptionService.shouldShowPaywall() {
                showingPaywall = true
                subscriptionService.markPaywallDisplayed()
            }
        }
    }

    /// Called when the gift button is tapped.
    func showPaywall() {
        showingPaywall = true
    }

    /// Handle long-press on gift button to toggle test mode.
    func toggleTestMode() {
        hapticService.playTestModeToggle()
        if subscriptionService.isTestModeEnabled {
            subscriptionService.setTestMode(false)
        } else {
            subscriptionService.setTestMode(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Paywall.testModePaywallDelay) { [weak self] in
                self?.showingPaywall = true
            }
        }
    }

    /// Called when the paywall sheet is dismissed.
    func onPaywallDismiss() {
        Task { @MainActor in
            isPremium = await subscriptionService.checkPremiumStatus()
        }
    }

    /// Mark a purchase as successful (show success overlay).
    func markPurchaseSuccess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Paywall.purchaseSuccessDelay) { [weak self] in
            self?.showPurchaseSuccess = true
        }
    }

    /// Dismiss the purchase success overlay.
    func dismissPurchaseSuccess() {
        showPurchaseSuccess = false
    }
}
