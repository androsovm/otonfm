import SwiftUI

/// Full color palette for the Oton.FM app.
/// All tokens correspond to UX_DESIGN.md section 2.1.
enum AppColors {

    // MARK: - Backgrounds

    /// Primary app background (#121212).
    static let backgroundPrimary = Color(r: 18, g: 18, b: 18)
    /// Elevated surface (#282828).
    static let backgroundElevated = Color(r: 40, g: 40, b: 40)
    /// Splash gradient top (#121212).
    static let splashTop = Color(r: 18, g: 18, b: 18)
    /// Splash gradient bottom (#191414).
    static let splashBottom = Color(r: 25, g: 20, b: 20)

    // MARK: - Surfaces

    /// Card background (ErrorView, PaywallSuccess): black @ 90%.
    static let surfaceCard = Color.black.opacity(0.9)
    /// Overlay background: black @ 70%.
    static let surfaceOverlay = Color.black.opacity(0.7)

    // MARK: - Accent

    /// Primary accent color (red #CF2B2B).
    static let accentPrimary = Color(r: 207, g: 43, b: 43)
    /// Splash glow: red #D00000 @ 30%.
    static let splashGlow = Color(red: 208.0 / 255, green: 0, blue: 0).opacity(0.3)

    // MARK: - Text

    /// Primary text color (white).
    static let textPrimary = Color.white
    /// Secondary text color (gray #808080).
    static let textSecondary = Color.gray
    /// Tertiary text color (white @ 70%).
    static let textTertiary = Color.white.opacity(0.7)

    // MARK: - Buttons

    /// Play/Pause button background.
    static let buttonPrimaryBg = Color.white
    /// Play/Pause button icon foreground (#181818).
    static let buttonPrimaryFg = Color(r: 24, g: 24, b: 24)
    /// Gift button background.
    static let buttonGiftBg = Color.white
    /// Gift button icon foreground.
    static let buttonGiftFg = Color.black

    // MARK: - Status

    /// Error icon color.
    static let error = Color.red

    // MARK: - Launch

    /// System launch screen background color (0.070 per component).
    static let launchBackground = Color(red: 0.070, green: 0.070, blue: 0.070)

    // MARK: - UIColor equivalents for services that need UIKit

    /// Primary background as UIColor.
    static let backgroundPrimaryUI = UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 1)
    /// Primary accent as UIColor.
    static let accentPrimaryUI = UIColor(red: 207 / 255, green: 43 / 255, blue: 43 / 255, alpha: 1)
}
