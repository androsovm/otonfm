import SwiftUI
import CoreMotion

/// Observes device tilt via CMMotionManager and provides pitch/roll values.
/// Uses a reference attitude so the current holding position is always "zero".
@Observable
final class MotionManager {
    var pitch: Double = 0
    var roll: Double = 0

    private let manager = CMMotionManager()
    private let maxTilt: Double = 6
    private let multiplier: Double = 9
    private let smoothing: Double = 0.12
    private var referenceAttitude: CMAttitude?

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        referenceAttitude = nil

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            // Capture reference on first update — whatever angle the user holds the phone
            if self.referenceAttitude == nil {
                self.referenceAttitude = motion.attitude.copy() as? CMAttitude
            }

            // Delta from reference position
            let attitude = motion.attitude
            attitude.multiply(byInverseOf: self.referenceAttitude!)

            let targetRoll = max(-self.maxTilt, min(self.maxTilt, attitude.roll * self.multiplier))
            let targetPitch = max(-self.maxTilt, min(self.maxTilt, attitude.pitch * self.multiplier))

            // Smooth interpolation — removes jitter
            self.roll += (targetRoll - self.roll) * self.smoothing
            self.pitch += (targetPitch - self.pitch) * self.smoothing
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        referenceAttitude = nil
        pitch = 0
        roll = 0
    }
}
