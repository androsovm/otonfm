import UIKit

extension UIColor {
    var isLightColor: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.7
    }
} 