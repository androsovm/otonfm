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
    let liveActivityService: any LiveActivityServiceProtocol
    let networkClient: any NetworkClientProtocol

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
        self.liveActivityService = LiveActivityService()
    }

    /// Test initializer -- inject mock services.
    init(
        audioEngine: any AudioEngineProtocol,
        metadataService: any MetadataServiceProtocol,
        artworkService: any ArtworkServiceProtocol,
        nowPlayingService: any NowPlayingServiceProtocol,
        subscriptionService: any SubscriptionServiceProtocol,
        hapticService: any HapticServiceProtocol,
        liveActivityService: any LiveActivityServiceProtocol = StubLiveActivityService(),
        networkClient: any NetworkClientProtocol
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
        self.nowPlayingService = nowPlayingService
        self.subscriptionService = subscriptionService
        self.hapticService = hapticService
        self.liveActivityService = liveActivityService
        self.networkClient = networkClient
    }
}
