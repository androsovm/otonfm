import SwiftUI
import CoreMotion

/// Observes device tilt via CMMotionManager and provides pitch/roll values.
@Observable
final class MotionManager {
    var pitch: Double = 0
    var roll: Double = 0

    private let manager = CMMotionManager()
    private let maxTilt: Double = 12

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let clamp = self.maxTilt
            self.roll = max(-clamp, min(clamp, motion.attitude.roll * 20))
            self.pitch = max(-clamp, min(clamp, motion.attitude.pitch * 20))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        pitch = 0
        roll = 0
    }
}
