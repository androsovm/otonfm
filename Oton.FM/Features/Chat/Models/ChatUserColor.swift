import SwiftUI
import UIKit

/// Deterministic color assignment for chat user names.
enum ChatUserColor {

    private static let palette: [Color] = [
        Color(UIColor(red: 0.95, green: 0.48, blue: 0.22, alpha: 1.0)), // warm orange
        Color(UIColor(red: 0.85, green: 0.65, blue: 0.85, alpha: 1.0)), // soft purple
        Color(UIColor(red: 0.50, green: 0.68, blue: 0.85, alpha: 1.0)), // sky blue
        Color(UIColor(red: 0.95, green: 0.52, blue: 0.20, alpha: 1.0)), // amber
        Color(UIColor(red: 0.20, green: 0.80, blue: 0.90, alpha: 1.0)), // cyan
        Color(UIColor(red: 0.85, green: 0.60, blue: 0.30, alpha: 1.0)), // golden
        Color(UIColor(red: 0.10, green: 0.75, blue: 0.45, alpha: 1.0)), // emerald
        Color(UIColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1.0)), // rose
    ]

    /// Returns a consistent color for a given name using hash.
    static func color(for name: String) -> Color {
        let hash = abs(name.hashValue)
        return palette[hash % palette.count]
    }
}
