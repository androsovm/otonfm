import SwiftUI
import AVFoundation
import os

private let log = Logger(subsystem: "fm.oton", category: "PlayerVM")

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
    var nextTrackTitle: String = ""

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
    // MARK: - Internal state

    private var hasLoadedRealArtworkOnce = false
    private var lastTrackTitle = ""
    private var stateTask: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
    private var nextTrackTask: Task<Void, Never>?

    // MARK: - Init

    init(
        audioEngine: any AudioEngineProtocol,
        metadataService: any MetadataServiceProtocol,
        artworkService: any ArtworkServiceProtocol,
        nowPlayingService: any NowPlayingServiceProtocol,
        hapticService: any HapticServiceProtocol
    ) {
        self.audioEngine = audioEngine
        self.metadataService = metadataService
        self.artworkService = artworkService
        self.nowPlayingService = nowPlayingService
        self.hapticService = hapticService
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
        nextTrackTask?.cancel()
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
        nextTrackTask?.cancel()
        nextTrackTitle = ""
    }

    @MainActor
    private func handleAudioState(_ state: AudioState) {
        log.debug("audioState: \(String(describing: state))")
        switch state {
        case .idle:
            displayState = .idle
        case .connecting:
            displayState = .connecting
        case .playing:
            displayState = .playing
        case .buffering:
            displayState = .buffering
        case .paused:
            displayState = .paused
        case .error(let err):
            displayState = .error(err)
        }
    }

    @MainActor
    private func handleMetadata(_ items: [AVMetadataItem]) {
        guard let title = metadataService.trackTitle(from: items),
              !title.isEmpty,
              title != trackTitle else {
            let raw = items.compactMap { $0.stringValue ?? ($0.value as? String) }.joined(separator: ", ")
            log.debug("handleMetadata: skipped (same/empty/nil) raw=[\(raw)] current=\"\(self.trackTitle)\"")
            return
        }

        log.info("▶ NEW TRACK: \"\(title)\"")
        trackTitle = title
        lastTrackTitle = title
        hapticService.playTrackChanged()

        if title.contains("OtonFM") {
            log.info("  → OtonFM jingle, loading station logo")
            let result = artworkService.loadStationLogo()
            applyArtwork(result)
        } else {
            Task { @MainActor in
                do {
                    let apiTrack = try await metadataService.fetchCurrentTrack()
                    log.info("  API track: \"\(apiTrack.title)\" artwork=\(apiTrack.bestArtworkUrl ?? "nil")")
                    // Validate title match
                    if apiTrack.title == title || apiTrack.title == lastTrackTitle {
                        let result = await artworkService.loadArtwork(for: apiTrack)
                        log.info("  artwork loaded: type=\(String(describing: result.type))")
                        applyArtwork(result)
                    } else {
                        log.warning("  API title mismatch: API=\"\(apiTrack.title)\" ICY=\"\(title)\" last=\"\(self.lastTrackTitle)\"")
                    }
                } catch {
                    log.error("  fetchCurrentTrack failed: \(error.localizedDescription)")
                }
            }
        }

        nowPlayingService.update(
            title: title,
            artist: "Oton FM",
            artwork: artworkImage,
            isLiveStream: true
        )

        // Fetch next track info
        fetchNextTrackInfo()
    }

    private func fetchNextTrackInfo() {
        nextTrackTask?.cancel()
        nextTrackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let nextTrack = try await self.metadataService.fetchNextTrack()
                guard !Task.isCancelled else {
                    log.debug("fetchNextTrack: cancelled")
                    return
                }
                log.info("  next track: \"\(nextTrack.title)\"")
                self.nextTrackTitle = nextTrack.title
            } catch {
                guard !Task.isCancelled else { return }
                log.warning("  fetchNextTrack failed: \(error.localizedDescription)")
                self.nextTrackTitle = ""
            }
        }
    }

    @MainActor
    private func applyArtwork(_ result: ArtworkResult) {
        artworkImage = result.image
        artworkId = UUID()

        let prevDefault = isDefaultArtworkShown
        switch result.type {
        case .realArtwork:
            hasLoadedRealArtworkOnce = true
            isDefaultArtworkShown = false
        case .stationLogo:
            isDefaultArtworkShown = true
        case .defaultArtwork:
            isDefaultArtworkShown = true
        }
        log.info("  applyArtwork: type=\(String(describing: result.type)) isDefault=\(self.isDefaultArtworkShown) (was \(prevDefault))")

        if let avg = result.averageColor {
            artworkShadowColor = Color(avg)
        }

        nowPlayingService.update(
            title: trackTitle.isEmpty ? "Oton.FM" : trackTitle,
            artist: "Oton FM",
            artwork: artworkImage,
            isLiveStream: true
        )
    }
}
