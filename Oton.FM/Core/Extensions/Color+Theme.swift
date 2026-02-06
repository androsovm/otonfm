import SwiftUI

extension Color {
    /// Initialize a SwiftUI Color from 0-255 integer RGB components.
    init(r: Int, g: Int, b: Int, opacity: Double = 1.0) {
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: opacity
        )
    }
}
