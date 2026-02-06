import SwiftUI
import AVFoundation

/// Coordinates all services and exposes UI-ready state for PlayerView.
@Observable
final class PlayerViewModel {

    // MARK: - UI State

    var displayState: PlayerDisplayState = .idle
    var trackTitle: String = ""
    var artworkImage: UIImage
    var artworkId: UUID = UUID()
    var isDefaultArtworkShown: Bool = true
    var artworkShadowColor: Color = .black

    var isPlaying: Bool { displayState == .playing }
    var isConnecting: Bool { displayState == .connecting }
    var isBuffering: Bool { displayState == .buffering || displayState == .connecting }

    var currentError: AudioError? {
        if case .error(let err) = displayState { return err }
        return nil
    }

    /// Whether the share button should be enabled (playing with a known track).
    var canShare: Bool {
        isPlaying && !trackTitle.isEmpty
    }

    /// Text to share via the system share sheet.
    var shareText: String {
        "\(trackTitle) -- Сейчас на Oton FM\nСлушай якутское радио: https://oton.fm"
    }

    /// Trigger haptic for share button.
    func shareButtonTapped() {
        hapticService.playShareTap()
    }

    // MARK: - Dependencies

    private let audioEngine: any AudioEngineProtocol
    private let metadataService: any MetadataServiceProtocol
    private let artworkService: any ArtworkServiceProtocol
    private let nowPlayingService: any NowPlayingServiceProtocol
    private let hapticService: any HapticServiceProtocol
    private let liveActivityService: any LiveActivityServiceProtocol

    // MARK: - Internal state

    private var hasLoadedRealArtworkOnce = false
    private var lastTrackTitle = ""
    private var stateTask: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?

    // MARK: - Init

    init(
        audioEngine: any AudioEngineProtocol,
        metadataService: any MetadataServiceProtocol,
        artworkService: any ArtworkServiceProtocol,
        nowPlayingService: any NowPlayingServiceProtocol,
        hapticService: any HapticServiceProtocol,
        liveActivityService: any LiveActivityServiceProtocol = StubLiveActivityService()
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
        self.nowPlayingService = nowPlayingService
        self.hapticService = hapticService
        self.liveActivityService = liveActivityService
        self.artworkImage = artworkService.defaultArtwork
    }

    // MARK: - Lifecycle

    /// Start observing audio engine streams. Call from .onAppear / .task.
    func startObserving() {
        hapticService.prepare()

        nowPlayingService.configure(
            playAction: { [weak self] in self?.play() },
            pauseAction: { [weak self] in self?.pause() }
        )

        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await state in self.audioEngine.stateStream {
                self.handleAudioState(state)
            }
        }

        metadataTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await items in self.audioEngine.metadataStream {
                self.handleMetadata(items)
            }
        }
    }

    /// Cancel observation tasks. Call from .onDisappear.
    func stopObserving() {
        stateTask?.cancel()
        metadataTask?.cancel()
    }

    // MARK: - Actions

    func togglePlayback() {
        hapticService.playButtonPress()
        if isPlaying || isConnecting || displayState == .buffering {
            pause()
        } else {
            play()
        }
    }

    func retry() {
        play()
    }

    func touchDown() {
        hapticService.playButtonRelease()
    }

    func touchUp() {
        hapticService.playButtonRelease()
    }

    // MARK: - Private

    private func play() {
        guard let url = URL(string: Config.radioStreamURL) else { return }
        hasLoadedRealArtworkOnce = false
        Task {
            await audioEngine.play(url: url)
        }
    }

    private func pause() {
        audioEngine.pause()
        nowPlayingService.clear()
    }

    /// Compressed artwork data for Live Activity (small JPEG to stay under 4KB limit).
    private var liveActivityArtworkData: Data? {
        guard !isDefaultArtworkShown else { return nil }
        // Live Activity content state has a ~4KB limit; compress to small thumbnail
        let size = CGSize(width: 80, height: 80)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        artworkImage.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail?.jpegData(compressionQuality: 0.5)
    }

    @MainActor
    private func handleAudioState(_ state: AudioState) {
        switch state {
        case .idle:
            displayState = .idle
            liveActivityService.end()
        case .connecting:
            displayState = .connecting
        case .playing:
            displayState = .playing
            liveActivityService.update(trackTitle: trackTitle.isEmpty ? "Oton FM" : trackTitle, isPlaying: true, artworkData: liveActivityArtworkData)
        case .buffering:
            displayState = .buffering
        case .paused:
            displayState = .paused
            liveActivityService.update(trackTitle: trackTitle.isEmpty ? "Oton FM" : trackTitle, isPlaying: false, artworkData: liveActivityArtworkData)
        case .error(let err):
            displayState = .error(err)
            liveActivityService.end()
        }
    }

    @MainActor
    private func handleMetadata(_ items: [AVMetadataItem]) {
        guard let title = metadataService.trackTitle(from: items),
              !title.isEmpty,
              title != trackTitle else { return }

        trackTitle = title
        lastTrackTitle = title
        hapticService.playTrackChanged()

        if title.contains("OtonFM") {
            let result = artworkService.loadStationLogo()
            applyArtwork(result)
        } else {
            Task { @MainActor in
                let track = TrackInfo(title: title, artworkUrl: nil, artworkUrlLarge: nil)
                // Fetch from API
                do {
                    let apiTrack = try await metadataService.fetchCurrentTrack()
                    // Validate title match
                    if apiTrack.title == title || apiTrack.title == lastTrackTitle {
                        let result = await artworkService.loadArtwork(for: apiTrack)
                        applyArtwork(result)
                    }
                } catch {
                    // Artwork fetch failed; keep current artwork
                }
            }
        }

        nowPlayingService.update(
            title: title,
            artist: "Oton FM",
            artwork: artworkImage,
            isLiveStream: true
        )

        // Update Live Activity with new track title
        if isPlaying {
            liveActivityService.update(trackTitle: title, isPlaying: true, artworkData: liveActivityArtworkData)
        }
    }

    @MainActor
    private func applyArtwork(_ result: ArtworkResult) {
        artworkImage = result.image
        artworkId = UUID()

        switch result.type {
        case .realArtwork:
            hasLoadedRealArtworkOnce = true
            isDefaultArtworkShown = false
        case .stationLogo:
            isDefaultArtworkShown = !hasLoadedRealArtworkOnce
        case .defaultArtwork:
            isDefaultArtworkShown = true
        }

        if let avg = result.averageColor {
            artworkShadowColor = Color(avg)
        }

        nowPlayingService.update(
            title: trackTitle.isEmpty ? "Oton.FM" : trackTitle,
            artist: "Oton FM",
            artwork: artworkImage,
            isLiveStream: true
        )

        // Update Live Activity with new artwork
        if isPlaying {
            liveActivityService.update(
                trackTitle: trackTitle.isEmpty ? "Oton FM" : trackTitle,
                isPlaying: true,
                artworkData: liveActivityArtworkData
            )
        }
    }
}
