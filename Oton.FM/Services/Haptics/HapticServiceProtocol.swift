import Foundation

/// Centralized haptic feedback patterns for the entire app.
protocol HapticServiceProtocol {
    /// Medium impact when a new track is detected.
    func playTrackChanged()

    /// Complex two-step pattern (heavy + light) for play/pause action.
    func playButtonPress()

    /// Light impact for touch-down and touch-up feedback.
    func playButtonRelease()

    /// Light impact for share button tap.
    func playShareTap()

    /// Heavy impact for test mode toggle.
    func playTestModeToggle()

    /// Prepare the haptic engine (call on appear).
    func prepare()
}
