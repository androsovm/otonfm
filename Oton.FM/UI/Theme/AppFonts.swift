import SwiftUI
import RevenueCatUI

/// Typography constants used throughout the app.
enum AppFonts {
    /// Track title / "OTON FM" / "Kholbonuu...": system 22pt bold.
    static let trackTitle = Font.system(size: 22, weight: .bold)
    /// Purchase success heading: system 24pt bold.
    static let successTitle = Font.system(size: 24, weight: .bold)
    /// Body text (purchase subtitle, "Continue" button): system 16pt.
    static let body = Font.system(size: 16)
    /// Retry button in ErrorView: system 16pt semibold.
    static let buttonLabel = Font.system(size: 16, weight: .semibold)
    /// Play/Pause icon: system 30pt bold.
    static let playIcon = Font.system(size: 30, weight: .bold)
    /// Gift icon: system 18pt bold.
    static let giftIcon = Font.system(size: 18, weight: .bold)
    /// Next track subtitle: system 14pt regular.
    static let nextTrackSubtitle = Font.system(size: 14, weight: .regular)
}

/// Rounded font provider for RevenueCat PaywallView.
struct RoundedFontProvider: PaywallFontProvider {
    func font(for textStyle: Font.TextStyle) -> Font {
        switch textStyle {
        case .largeTitle:
            return .system(size: 34, weight: .bold, design: .rounded)
        case .title:
            return .system(size: 28, weight: .bold, design: .rounded)
        case .title2:
            return .system(size: 22, weight: .bold, design: .rounded)
        case .title3:
            return .system(size: 20, weight: .semibold, design: .rounded)
        case .headline:
            return .system(size: 17, weight: .semibold, design: .rounded)
        case .body:
            return .system(size: 17, weight: .regular, design: .rounded)
        case .callout:
            return .system(size: 16, weight: .regular, design: .rounded)
        case .subheadline:
            return .system(size: 15, weight: .regular, design: .rounded)
        case .footnote:
            return .system(size: 13, weight: .regular, design: .rounded)
        case .caption:
            return .system(size: 12, weight: .regular, design: .rounded)
        case .caption2:
            return .system(size: 11, weight: .regular, design: .rounded)
        @unknown default:
            return .system(size: 17, weight: .regular, design: .rounded)
        }
    }
}
