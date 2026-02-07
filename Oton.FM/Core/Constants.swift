import Foundation

/// All magic numbers collected in one place.
/// Organized by functional category for easy discovery.
enum Constants {

    // MARK: - Audio & Network

    enum Audio {
        /// Preferred forward buffer duration for AVPlayer (seconds).
        static let bufferDuration: TimeInterval = 30.0
        /// How often to check buffer status (seconds).
        static let bufferCheckInterval: TimeInterval = 0.5
        /// Base delay for first reconnection attempt (seconds). Grows exponentially.
        static let reconnectBaseDelay: TimeInterval = 2.0
        /// Maximum automatic reconnect attempts before surfacing error.
        static let maxReconnectAttempts = 7
        /// Maximum artwork download retries with progressive back-off.
        static let maxArtworkRetries = 3
        /// HTTP request timeout (seconds).
        static let apiTimeout: TimeInterval = 10.0
        /// Delay before auto-retry after network recovery (seconds).
        static let networkRecoveryDelay: TimeInterval = 1.5
    }

    // MARK: - Animation Timings

    enum Animation {
        /// Interval between Yakutia gradient changes (seconds).
        static let gradientChangeInterval: TimeInterval = 10.0
        /// Duration of gradient cross-fade transition (seconds).
        static let gradientTransitionDuration: TimeInterval = 3.0
        /// Splash screen display duration (seconds).
        static let splashDuration: TimeInterval = 2.0
        /// Splash screen fade-out duration (seconds).
        static let splashFadeOut: TimeInterval = 0.5
        /// Main interface fade-in after splash (seconds).
        static let interfaceAppear: TimeInterval = 1.0
        /// Artwork cross-fade when track changes (seconds).
        static let artworkTransition: TimeInterval = 0.6
        /// Track title text transition duration (seconds).
        static let textTransition: TimeInterval = 0.5
        /// Background color transition when artwork changes (seconds).
        static let backgroundTransition: TimeInterval = 0.8
        /// Play button press animation duration (seconds).
        static let pressAnimation: TimeInterval = 0.2
        /// AnimatedDots tick interval (seconds).
        static let dotsInterval: TimeInterval = 0.4
        /// Splash RadialGradient pulse period (seconds).
        static let splashPulseDuration: TimeInterval = 1.0
        /// Splash logo animation duration (seconds).
        static let splashLogoDuration: TimeInterval = 1.2
    }

    // MARK: - Layout

    enum Layout {
        /// Artwork width & height = screenWidth * this ratio.
        static let artworkSizeRatio: CGFloat = 0.85
        /// Horizontal padding = screenWidth * this ratio.
        static let horizontalPaddingRatio: CGFloat = 0.075
        /// Track info vertical offset (negative = up).
        static let trackInfoOffset: CGFloat = -40
        /// Track info area fixed height.
        static let trackInfoHeight: CGFloat = 60
        /// Play/Pause button diameter.
        static let playButtonSize: CGFloat = 64
        /// Play/Pause icon font size.
        static let playIconSize: CGFloat = 30
        /// Play icon horizontal offset for visual centering.
        static let playIconOffset: CGFloat = 2
        /// Artwork SwiftUI corner radius.
        static let artworkCornerRadius: CGFloat = 32
        /// Artwork UIImage corner radius = width * this ratio.
        static let artworkCornerRadiusRatio: CGFloat = 0.062
        /// Artwork shadow blur radius.
        static let artworkShadowRadius: CGFloat = 25
        /// Artwork shadow opacity.
        static let artworkShadowOpacity: Double = 0.6
        /// Artwork shadow vertical offset.
        static let artworkShadowOffsetY: CGFloat = 10
        /// Play button press-down scale.
        static let pressScale: CGFloat = 0.9
        /// Logo size on splash screen.
        static let logoSplashSize: CGFloat = 100
        /// Spacing between TrackInfo and Controls / bottom padding.
        static let bottomSpacing: CGFloat = 30
        /// Top bar padding from the top edge.
        static let topBarPaddingTop: CGFloat = 20
        /// Gift icon font size.
        static let giftIconSize: CGFloat = 18
        /// Gift button horizontal padding.
        static let giftPaddingH: CGFloat = 12
        /// Gift button vertical padding.
        static let giftPaddingV: CGFloat = 8
        /// Card corner radius (ErrorView, PurchaseSuccess).
        static let cardCornerRadius: CGFloat = 20
        /// Error icon font size.
        static let errorIconSize: CGFloat = 50
        /// Success checkmark icon frame size.
        static let successIconSize: CGFloat = 80
        /// ProgressView scale inside buffering button.
        static let bufferingSpinnerScale: CGFloat = 1.2
        /// Share icon font size.
        static let shareIconSize: CGFloat = 20
        /// Secondary button hit area (share, sleep timer).
        static let secondaryButtonSize: CGFloat = 44
        /// Horizontal spacing between controls in the controls row.
        static let controlsHorizontalSpacing: CGFloat = 30
    }

    // MARK: - Shadows

    enum Shadow {
        /// Card shadow blur radius.
        static let cardRadius: CGFloat = 20
        /// Card shadow opacity.
        static let cardOpacity: Double = 0.5
        /// Card shadow vertical offset.
        static let cardOffsetY: CGFloat = 10
    }

    // MARK: - Opacity

    enum Opacity {
        /// Top color opacity when using artwork-based background.
        static let backgroundArtwork: Double = 0.8
        /// ErrorView card background opacity.
        static let cardBackground: Double = 0.9
        /// PurchaseSuccess overlay background opacity.
        static let overlayBackground: Double = 0.7
        /// Tertiary text opacity (hints, suggestions).
        static let textTertiary: Double = 0.7
        /// Splash glow min opacity.
        static let splashGlowMin: Double = 0.3
        /// Splash glow max opacity.
        static let splashGlowMax: Double = 0.7
    }

    // MARK: - Paywall

    enum Paywall {
        /// Days after first launch when paywall auto-shows.
        static let targetDays = [3, 6, 15]
        /// Delay before paywall eligibility check (seconds).
        static let checkDelay: TimeInterval = 1.0
        /// Delay before showing purchase success overlay (seconds).
        static let purchaseSuccessDelay: TimeInterval = 0.3
        /// Delay before showing paywall after test mode activation (seconds).
        static let testModePaywallDelay: TimeInterval = 0.5
        /// Long-press duration to toggle test mode (seconds).
        static let longPressDuration: TimeInterval = 1.5
        /// Window (seconds) to detect a recent purchase after paywall dismiss.
        static let purchaseDetectionWindow: TimeInterval = 10.0
    }

    // MARK: - Haptics

    enum Haptics {
        /// Delay between heavy and light impacts in complex pattern (seconds).
        static let complexPatternDelay: TimeInterval = 0.1
    }

    // MARK: - Dots Animation

    enum Dots {
        /// Number of animated dots.
        static let count = 3
        /// Total states in the dot cycle (0 = all hidden, 1..count = progressive reveal).
        static let stateCount = 4
        /// Spacing between dots.
        static let spacing: CGFloat = 2
    }

    // MARK: - Splash

    enum Splash {
        /// Splash RadialGradient start radius.
        static let glowStartRadius: CGFloat = 50
        /// Splash RadialGradient end radius.
        static let glowEndRadius: CGFloat = 180
        /// Logo scale range start.
        static let logoScaleFrom: CGFloat = 0.9
        /// Logo scale range end.
        static let logoScaleTo: CGFloat = 1.1
        /// Logo opacity start.
        static let logoOpacityFrom: Double = 0.8
        /// Logo opacity end.
        static let logoOpacityTo: Double = 1.0
        /// Glow scale range start.
        static let glowScaleFrom: CGFloat = 1.0
        /// Glow scale range end.
        static let glowScaleTo: CGFloat = 1.2
    }
}
