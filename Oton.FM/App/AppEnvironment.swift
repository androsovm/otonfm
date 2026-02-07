import SwiftUI

/// Dependency injection container.
/// Creates all production services and exposes them via protocol types.
/// Injected into the SwiftUI view hierarchy via `.environment()`.
@Observable
final class AppEnvironment {
    let audioEngine: any AudioEngineProtocol
    let metadataService: any MetadataServiceProtocol
    let artworkService: any ArtworkServiceProtocol
    let nowPlayingService: any NowPlayingServiceProtocol
    let subscriptionService: any SubscriptionServiceProtocol
    let hapticService: any HapticServiceProtocol
    let networkClient: any NetworkClientProtocol
    let chatService: any ChatServiceProtocol
    let authService: any AuthServiceProtocol

    /// Production initializer -- creates real service instances.
    init() {
        let network = NetworkClient()
        self.networkClient = network
        self.audioEngine = AudioEngine()
        self.metadataService = MetadataService(networkClient: network)
        self.artworkService = ArtworkService(networkClient: network)
        self.nowPlayingService = NowPlayingService()
        self.subscriptionService = SubscriptionService()
        self.hapticService = HapticService()
        let auth = AuthService()
        self.authService = auth
        self.chatService = FirebaseChatService(authService: auth)
    }

    /// Test initializer -- inject mock services.
    init(
        audioEngine: any AudioEngineProtocol,
        metadataService: any MetadataServiceProtocol,
        artworkService: any ArtworkServiceProtocol,
        nowPlayingService: any NowPlayingServiceProtocol,
        subscriptionService: any SubscriptionServiceProtocol,
        hapticService: any HapticServiceProtocol,
        networkClient: any NetworkClientProtocol,
        chatService: any ChatServiceProtocol = StubChatService(),
        authService: any AuthServiceProtocol = StubAuthService()
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
        self.nowPlayingService = nowPlayingService
        self.subscriptionService = subscriptionService
        self.hapticService = hapticService
        self.networkClient = networkClient
        self.chatService = chatService
        self.authService = authService
    }
}
