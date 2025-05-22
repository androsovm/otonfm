import SwiftUI
import RevenueCatUI

// Font provider для PaywallView
struct RoundedFontProvider: PaywallFontProvider {
    func font(for textStyle: Font.TextStyle) -> Font {
        switch textStyle {
        case .largeTitle:
            return Font.system(size: 34, weight: .bold, design: .rounded)
        case .title:
            return Font.system(size: 28, weight: .bold, design: .rounded)
        case .title2:
            return Font.system(size: 22, weight: .bold, design: .rounded)
        case .title3:
            return Font.system(size: 20, weight: .semibold, design: .rounded)
        case .headline:
            return Font.system(size: 17, weight: .semibold, design: .rounded)
        case .body:
            return Font.system(size: 17, weight: .regular, design: .rounded)
        case .callout:
            return Font.system(size: 16, weight: .regular, design: .rounded)
        case .subheadline:
            return Font.system(size: 15, weight: .regular, design: .rounded)
        case .footnote:
            return Font.system(size: 13, weight: .regular, design: .rounded)
        case .caption:
            return Font.system(size: 12, weight: .regular, design: .rounded)
        case .caption2:
            return Font.system(size: 11, weight: .regular, design: .rounded)
        @unknown default:
            return Font.system(size: 17, weight: .regular, design: .rounded)
        }
    }
}