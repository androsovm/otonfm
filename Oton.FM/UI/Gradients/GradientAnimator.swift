import SwiftUI

/// Manages the animated cycling through YakutiaGradients.
/// Picks a random start, advances sequentially, interpolates over 3s transitions.
@Observable
final class GradientAnimator {
    var currentIndex: Int
    var nextIndex: Int
    var transition: Double = 0.0

    private var timer: Timer?

    init() {
        let start = Int.random(in: 0..<YakutiaGradients.count)
        self.currentIndex = start
        self.nextIndex = (start + 1) % YakutiaGradients.count
    }

    /// Start the gradient rotation timer.
    func start() {
        stop()
        randomizeStart()
        timer = Timer.scheduledTimer(
            withTimeInterval: Constants.Animation.gradientChangeInterval,
            repeats: true
        ) { [weak self] _ in
            self?.advance()
        }
    }

    /// Stop the gradient rotation timer.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Pick a new random starting gradient (called when default artwork appears).
    func randomizeStart() {
        let start = Int.random(in: 0..<YakutiaGradients.count)
        currentIndex = start
        nextIndex = (start + 1) % YakutiaGradients.count
        transition = 0.0
    }

    /// Build the interpolated LinearGradient for the current animation frame.
    func interpolatedGradient() -> LinearGradient {
        let from = YakutiaGradients.all[currentIndex]
        let to = YakutiaGradients.all[nextIndex]
        let t = CGFloat(transition)

        let topColor = Color(YakutiaGradients.lerpColor(from.topColor, to.topColor, t: t))
        let bottomColor = Color(YakutiaGradients.lerpColor(from.bottomColor, to.bottomColor, t: t))

        return LinearGradient(
            gradient: Gradient(colors: [topColor, bottomColor]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Private

    private func advance() {
        withAnimation(.easeInOut(duration: Constants.Animation.gradientTransitionDuration)) {
            transition = 1.0
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.Animation.gradientTransitionDuration
        ) { [weak self] in
            guard let self else { return }
            self.currentIndex = self.nextIndex
            self.nextIndex = (self.currentIndex + 1) % YakutiaGradients.count
            self.transition = 0.0
        }
    }
}
