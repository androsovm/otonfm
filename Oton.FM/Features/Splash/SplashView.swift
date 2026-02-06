import SwiftUI

/// Animated splash screen shown for 2 seconds with pulsating glow and logo.
struct SplashView: View {
    @State private var animate = false
    @State private var pulseAnimation = false
    @Binding var isActive: Bool

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                gradient: Gradient(colors: [AppColors.splashTop, AppColors.splashBottom]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Pulsating radial glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 208 / 255, green: 0, blue: 0).opacity(Constants.Opacity.splashGlowMin),
                    Color.clear
                ]),
                center: .center,
                startRadius: Constants.Splash.glowStartRadius,
                endRadius: Constants.Splash.glowEndRadius
            )
            .scaleEffect(pulseAnimation ? Constants.Splash.glowScaleTo : Constants.Splash.glowScaleFrom)
            .opacity(pulseAnimation ? Constants.Opacity.splashGlowMax : Constants.Opacity.splashGlowMin)
            .animation(
                .easeInOut(duration: Constants.Animation.splashPulseDuration)
                    .repeatForever(autoreverses: true),
                value: pulseAnimation
            )

            // Logo
            VStack(spacing: 20) {
                Image("otonLogo-Light")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: Constants.Layout.logoSplashSize,
                        height: Constants.Layout.logoSplashSize
                    )
                    .scaleEffect(animate ? Constants.Splash.logoScaleTo : Constants.Splash.logoScaleFrom)
                    .opacity(animate ? Constants.Splash.logoOpacityTo : Constants.Splash.logoOpacityFrom)
                    .animation(
                        .easeInOut(duration: Constants.Animation.splashLogoDuration)
                            .repeatCount(1, autoreverses: false),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
            pulseAnimation = true

            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Animation.splashDuration) {
                withAnimation(.easeInOut(duration: Constants.Animation.splashFadeOut)) {
                    isActive = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
