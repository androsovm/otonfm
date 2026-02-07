import SwiftUI
import RevenueCatUI

/// Main player screen -- the only screen the user interacts with.
struct PlayerView: View {
    @State private var viewModel: PlayerViewModel
    @State private var subscriptionVM: SubscriptionViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var gradientAnimator = GradientAnimator()
    @State private var motionManager = MotionManager()
    @State private var isInterfaceVisible = false
    @State private var isChatSheetPresented = false

    init(viewModel: PlayerViewModel) {
        _viewModel = State(initialValue: viewModel)
        _subscriptionVM = State(initialValue: SubscriptionViewModel(
            subscriptionService: StubSubscriptionService(),
            hapticService: StubHapticService()
        ))
        _chatViewModel = State(initialValue: ChatViewModel(
            chatService: StubChatService()
        ))
    }

    init(viewModel: PlayerViewModel, subscriptionVM: SubscriptionViewModel) {
        _viewModel = State(initialValue: viewModel)
        _subscriptionVM = State(initialValue: subscriptionVM)
        _chatViewModel = State(initialValue: ChatViewModel(
            chatService: StubChatService()
        ))
    }

    init(viewModel: PlayerViewModel, subscriptionVM: SubscriptionViewModel, chatViewModel: ChatViewModel) {
        _viewModel = State(initialValue: viewModel)
        _subscriptionVM = State(initialValue: subscriptionVM)
        _chatViewModel = State(initialValue: chatViewModel)
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
            chatViewModel.startObserving()
            motionManager.start()
        }
        .onDisappear {
            viewModel.stopObserving()
            chatViewModel.stopObserving()
            motionManager.stop()
        }
        .onAppear {
            withAnimation {
                isInterfaceVisible = true
            }
            if viewModel.isDefaultArtworkShown {
                gradientAnimator.start()
            }
            subscriptionVM.checkAndShowPaywall()
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
        .sheet(isPresented: $isChatSheetPresented) {
            ChatView(viewModel: chatViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.ultraThinMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
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
            ZStack {
                Color.clear
                    .overlay(
                        Image(uiImage: viewModel.artworkImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .scaleEffect(1.3)
                    )
                    .clipped()
                    .id(viewModel.artworkId)

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                // Top bar: share + admin status + gift buttons
                HStack {
                    shareButton
                    Spacer()
                    if let status = chatViewModel.adminStatus {
                        AdminStatusBanner(status: status)
                            .transition(.opacity)
                    }
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
                    shadowColor: viewModel.artworkShadowColor,
                    motionManager: motionManager
                )

                Spacer()

                // Bottom: track info + controls + chat pill
                VStack(spacing: Constants.Layout.bottomSpacing) {
                    TrackInfoView(
                        isConnecting: viewModel.isConnecting,
                        isPlaying: viewModel.isPlaying,
                        trackTitle: viewModel.trackTitle,
                        nextTrackTitle: viewModel.nextTrackTitle
                    )

                    PlayerControlsView(
                        isPlaying: viewModel.isPlaying,
                        isBuffering: viewModel.isBuffering,
                        onToggle: viewModel.togglePlayback,
                        onTouchDown: viewModel.touchDown,
                        onTouchUp: viewModel.touchUp
                    )

                    ChatPillBar(
                        lastMessagePreview: chatViewModel.messages.last?.text,
                        unreadCount: chatViewModel.unreadCount,
                        onTap: { isChatSheetPresented = true }
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
