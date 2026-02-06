import SwiftUI
import RevenueCatUI

/// Main player screen -- the only screen the user interacts with.
struct PlayerView: View {
    @State private var viewModel: PlayerViewModel
    @State private var subscriptionVM: SubscriptionViewModel
    @State private var gradientAnimator = GradientAnimator()
    @State private var pulsateAnimation = false
    @State private var isInterfaceVisible = false

    init(viewModel: PlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
        // SubscriptionViewModel is created with stubs here;
        // the real wiring happens from the environment in OtonFMApp.
        _subscriptionVM = State(initialValue: SubscriptionViewModel(
            subscriptionService: StubSubscriptionService(),
            hapticService: StubHapticService()
        ))
    }

    init(viewModel: PlayerViewModel, subscriptionVM: SubscriptionViewModel) {
        _viewModel = State(initialValue: viewModel)
        _subscriptionVM = State(initialValue: subscriptionVM)
    }

    var body: some View {
        ZStack {
            // Layer 0: Background gradient
            backgroundLayer
                .ignoresSafeArea()

            // Layer 1: Purchase success overlay
            if subscriptionVM.showPurchaseSuccess {
                PurchaseSuccessView(onDismiss: subscriptionVM.dismissPurchaseSuccess)
                    .zIndex(2)
            }

            // Layer 2: Error overlay
            if let error = viewModel.currentError {
                ErrorView(error: error, retry: viewModel.retry)
                    .transition(.scale.combined(with: .opacity))
            }

            // Layer 3: Main interface
            if isInterfaceVisible {
                mainInterface
                    .transition(.opacity)
                    .animation(.easeInOut(duration: Constants.Animation.interfaceAppear), value: isInterfaceVisible)
            }
        }
        .task {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .onAppear {
            withAnimation {
                isInterfaceVisible = true
            }
            pulsateAnimation = viewModel.isPlaying
            if viewModel.isDefaultArtworkShown {
                gradientAnimator.start()
            }
            subscriptionVM.checkAndShowPaywall()
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            pulsateAnimation = isPlaying
        }
        .onChange(of: viewModel.isDefaultArtworkShown) { _, isDefault in
            if isDefault {
                gradientAnimator.randomizeStart()
                gradientAnimator.start()
            } else {
                gradientAnimator.stop()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if viewModel.isDefaultArtworkShown {
            ZStack {
                gradientAnimator.interpolatedGradient()
                    .animation(.easeInOut(duration: Constants.Animation.backgroundTransition), value: gradientAnimator.currentIndex)

                backgroundAnimationOverlay
            }
        } else {
            LinearGradient(
                gradient: Gradient(colors: [
                    viewModel.artworkShadowColor.opacity(Constants.Opacity.backgroundArtwork),
                    AppColors.backgroundPrimary
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(.easeInOut(duration: Constants.Animation.backgroundTransition), value: viewModel.artworkId)
        }
    }

    // MARK: - Background Animation

    @ViewBuilder
    private var backgroundAnimationOverlay: some View {
        let currentAnim = YakutiaGradients.all[gradientAnimator.currentIndex].animation
        let nextAnim = YakutiaGradients.all[gradientAnimator.nextIndex].animation
        let t = gradientAnimator.transition

        let starsOpacity: Double = {
            var v = 0.0
            if currentAnim == .stars { v += 1.0 - t }
            if nextAnim == .stars { v += t }
            return v
        }()

        let snowOpacity: Double = {
            var v = 0.0
            if currentAnim == .snow { v += 1.0 - t }
            if nextAnim == .snow { v += t }
            return v
        }()

        StarrySkyView()
            .opacity(starsOpacity)

        FallingSnowView()
            .opacity(snowOpacity)
    }

    // MARK: - Main Interface

    private var mainInterface: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar: share + gift buttons
                HStack {
                    shareButton
                    Spacer()
                    giftButton
                }
                .padding(.horizontal, UIScreen.main.bounds.width * Constants.Layout.horizontalPaddingRatio)
                .padding(.top, Constants.Layout.topBarPaddingTop)

                Spacer()

                // Artwork
                ArtworkView(
                    image: viewModel.artworkImage,
                    artworkId: viewModel.artworkId,
                    isPlaying: viewModel.isPlaying,
                    isDefaultArtwork: viewModel.isDefaultArtworkShown,
                    pulsateAnimation: $pulsateAnimation,
                    shadowColor: viewModel.artworkShadowColor
                )

                Spacer()

                // Bottom: track info + controls
                VStack(spacing: Constants.Layout.bottomSpacing) {
                    TrackInfoView(
                        isConnecting: viewModel.isConnecting,
                        isPlaying: viewModel.isPlaying,
                        trackTitle: viewModel.trackTitle
                    )

                    PlayerControlsView(
                        isPlaying: viewModel.isPlaying,
                        isBuffering: viewModel.isBuffering,
                        onToggle: viewModel.togglePlayback,
                        onTouchDown: viewModel.touchDown,
                        onTouchUp: viewModel.touchUp,
                        pulsateAnimation: $pulsateAnimation
                    )
                    .padding(.bottom, Constants.Layout.bottomSpacing)
                }
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        ShareLink(item: viewModel.shareText) {
            Image(systemName: "square.and.arrow.up")
                .font(AppFonts.giftIcon)
                .foregroundColor(viewModel.canShare ? AppColors.buttonGiftFg : AppColors.buttonGiftFg.opacity(0.3))
                .padding(.horizontal, Constants.Layout.giftPaddingH)
                .padding(.vertical, Constants.Layout.giftPaddingV)
                .background(AppColors.buttonGiftBg)
                .clipShape(Capsule())
        }
        .disabled(!viewModel.canShare)
        .simultaneousGesture(TapGesture().onEnded {
            if viewModel.canShare { viewModel.shareButtonTapped() }
        })
    }

    // MARK: - Gift Button

    private var giftButton: some View {
        Button(action: { subscriptionVM.showPaywall() }) {
            Image(systemName: "gift.fill")
                .font(AppFonts.giftIcon)
                .foregroundColor(AppColors.buttonGiftFg)
                .padding(.horizontal, Constants.Layout.giftPaddingH)
                .padding(.vertical, Constants.Layout.giftPaddingV)
                .background(AppColors.buttonGiftBg)
                .clipShape(Capsule())
        }
        .onLongPressGesture(minimumDuration: Constants.Paywall.longPressDuration) {
            subscriptionVM.toggleTestMode()
        }
        .sheet(isPresented: $subscriptionVM.showingPaywall, onDismiss: {
            subscriptionVM.onPaywallDismiss()
        }) {
            PaywallView(
                fonts: RoundedFontProvider(),
                displayCloseButton: true
            )
        }
    }
}
