import SwiftUI
import RevenueCatUI

/// Wrapper around RevenueCatUI's PaywallView with the app's custom font provider.
struct PaywallContainerView: View {
    var onDismiss: () -> Void

    var body: some View {
        PaywallView(
            fonts: RoundedFontProvider(),
            displayCloseButton: true
        )
    }
}
