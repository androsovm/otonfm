import SwiftUI

/// ViewModifier that applies a subtle pulsating scale effect when active.
struct PulsationModifier: ViewModifier {
    let isActive: Bool

    @State private var isPulsating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isPulsating ? Constants.Layout.pulsationScale : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: Constants.Animation.pulsationDuration)
                        .repeatForever(autoreverses: true)
                    : .default,
                value: isPulsating
            )
            .onChange(of: isActive) { _, active in
                isPulsating = active
            }
            .onAppear {
                isPulsating = isActive
            }
    }
}

extension View {
    /// Apply a gentle pulsating scale effect, toggled by `isActive`.
    func pulsating(when isActive: Bool) -> some View {
        modifier(PulsationModifier(isActive: isActive))
    }
}
