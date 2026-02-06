import UIKit

/// Production haptic feedback service with all app haptic patterns.
final class HapticService: HapticServiceProtocol {

    private var impactLight: UIImpactFeedbackGenerator?
    private var impactMedium: UIImpactFeedbackGenerator?
    private var impactHeavy: UIImpactFeedbackGenerator?

    func prepare() {
        impactLight = UIImpactFeedbackGenerator(style: .light)
        impactMedium = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        impactLight?.prepare()
        impactMedium?.prepare()
        impactHeavy?.prepare()
    }

    func playTrackChanged() {
        impactMedium?.impactOccurred()
    }

    func playButtonPress() {
        impactHeavy?.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Haptics.complexPatternDelay) { [weak self] in
            self?.impactLight?.impactOccurred()
        }
    }

    func playButtonRelease() {
        impactLight?.impactOccurred()
    }

    func playShareTap() {
        impactLight?.impactOccurred()
    }

    func playTestModeToggle() {
        impactHeavy?.impactOccurred()
    }
}

/// Stub for compilation before Task #11.
final class StubHapticService: HapticServiceProtocol {
    func playTrackChanged() {}
    func playButtonPress() {}
    func playButtonRelease() {}
    func playShareTap() {}
    func playTestModeToggle() {}
    func prepare() {}
}
