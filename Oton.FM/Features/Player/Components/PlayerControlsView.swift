import SwiftUI

/// Circular Play/Pause button with buffering spinner and haptic feedback.
struct PlayerControlsView: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let onToggle: () -> Void
    let onTouchDown: () -> Void
    let onTouchUp: () -> Void
    @Binding var pulsateAnimation: Bool

    @State private var isPressed = false

    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(AppColors.buttonPrimaryBg)
                    .frame(
                        width: Constants.Layout.playButtonSize,
                        height: Constants.Layout.playButtonSize
                    )

                if isBuffering && isPlaying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.buttonPrimaryFg))
                        .scaleEffect(Constants.Layout.bufferingSpinnerScale)
                } else {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(AppFonts.playIcon)
                        .foregroundColor(AppColors.buttonPrimaryFg)
                        .offset(x: isPlaying ? 0 : Constants.Layout.playIconOffset)
                }
            }
            .scaleEffect(isPressed ? Constants.Layout.pressScale : 1.0)
            .animation(.easeOut(duration: Constants.Animation.pressAnimation), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onTouchDown()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onTouchUp()
                }
        )
    }
}
