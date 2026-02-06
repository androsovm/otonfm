import UIKit

extension UIColor {
    /// Returns `true` when the color's perceived brightness exceeds 0.7.
    /// Useful for choosing contrasting text colors against dynamic backgrounds.
    var isLightColor: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.7
    }
}
