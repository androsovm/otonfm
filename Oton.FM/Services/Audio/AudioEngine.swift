import AVFoundation
import Network
import os

private let log = Logger(subsystem: "fm.oton", category: "AudioEngine")

/// Production audio engine managing AVPlayer, audio session, buffering, and reconnection.
/// Uses AsyncStream for state and metadata delivery instead of Combine/callbacks.
final class AudioEngine: NSObject, AudioEngineProtocol, @unchecked Sendable {

    // MARK: - Public state

    private(set) var state: AudioState = .idle {
        didSet {
            guard state != oldValue else { return }
            log.info("state: \(String(describing: self.state))")
            stateContinuation?.yield(state)
        }
    }

    let stateStream: AsyncStream<AudioState>
    let metadataStream: AsyncStream<[AVMetadataItem]>

    // MARK: - Private stream continuations

    private var stateContinuation: AsyncStream<AudioState>.Continuation?
    private var metadataContinuation: AsyncStream<[AVMetadataItem]>.Continuation?

    // MARK: - AVPlayer

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var currentURL: URL?
    private var reconnectAttempts = 0
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Network monitoring

    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private var wasDisconnectedDuringPlayback = false

    // MARK: - KVO tokens

    private var statusObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var metadataObservation: NSKeyValueObservation?
    private var stalledObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var errorLogObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    // MARK: - Init

    override init() {
        var sc: AsyncStream<AudioState>.Continuation!
        stateStream = AsyncStream { sc = $0 }

        var mc: AsyncStream<[AVMetadataItem]>.Continuation!
        metadataStream = AsyncStream { mc = $0 }

        super.init()

        stateContinuation = sc
        metadataContinuation = mc

        configureAudioSession()
        observeAudioSessionEvents()
        startNetworkMonitoring()
    }

    deinit {
        teardown()
        networkMonitor.cancel()
        stateContinuation?.finish()
        metadataContinuation?.finish()
    }

    // MARK: - AudioEngineProtocol

    func play(url: URL) async {
        teardown()

        currentURL = url
        reconnectAttempts = 0
        wasDisconnectedDuringPlayback = false
        state = .connecting

        setupPlayer(with: url)
        startBufferMonitoring()
        player?.play()
    }

    func pause() {
        reconnectTask?.cancel()
        reconnectTask = nil
        player?.pause()
        stopBufferMonitoring()
        wasDisconnectedDuringPlayback = false
        state = .paused
    }

    func stop() {
        teardown()
        state = .idle
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            log.error("failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func observeAudioSessionEvents() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            log.info("interruption began")
            if state == .playing || state == .buffering {
                player?.pause()
                state = .paused
            }
        case .ended:
            log.info("interruption ended")
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), state == .paused {
                    player?.play()
                    state = .playing
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        log.info("route change: \(reasonValue)")
        if reason == .oldDeviceUnavailable {
            // Headphones disconnected
            if state == .playing || state == .buffering {
                pause()
            }
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkChange(path)
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "fm.oton.network"))
    }

    private func handleNetworkChange(_ path: NWPath) {
        let available = path.status == .satisfied
        let previous = isNetworkAvailable
        isNetworkAvailable = available

        log.info("network: \(available ? "available" : "unavailable") (was \(previous ? "available" : "unavailable")), interfaces: \(path.availableInterfaces.map { $0.type.debugDescription })")

        if available && !previous {
            // Network recovered
            handleNetworkRecovery()
        } else if !available && previous {
            // Network lost
            if state.isActive {
                wasDisconnectedDuringPlayback = true
                log.warning("network lost during active playback")
            }
        }
    }

    private func handleNetworkRecovery() {
        guard wasDisconnectedDuringPlayback, let url = currentURL else { return }

        // Auto-reconnect if we were playing when network dropped
        let currentState = state
        if currentState == .buffering || currentState == .error(.networkUnavailable)
            || currentState == .error(.streamUnavailable) || currentState == .error(.bufferingTimeout) {

            log.info("network recovered → auto-reconnecting")
            reconnectAttempts = 0
            wasDisconnectedDuringPlayback = false
            state = .connecting

            reconnectTask?.cancel()
            reconnectTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(Constants.Audio.networkRecoveryDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.play(url: url)
            }
        }
    }

    // MARK: - Player Setup

    private func setupPlayer(with url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = Constants.Audio.bufferDuration
        playerItem = item

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        player = avPlayer

        addObservers(for: item)
    }

    private func addObservers(for item: AVPlayerItem) {
        // Status
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleStatusChange(item.status)
            }
        }

        // Buffer empty
        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, change in
            guard let isEmpty = change.newValue, isEmpty else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.state == .playing {
                    log.debug("buffer empty → buffering")
                    self.state = .buffering
                }
            }
        }

        // Likely to keep up
        likelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, change in
            guard let likely = change.newValue, likely else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.state == .connecting || self.state == .buffering {
                    log.debug("buffer ready → playing")
                    self.reconnectAttempts = 0
                    self.wasDisconnectedDuringPlayback = false
                    self.state = .playing
                }
            }
        }

        // Timed metadata (modern block-based KVO)
        metadataObservation = item.observe(\.timedMetadata, options: [.new]) { [weak self] item, _ in
            guard let self, let items = item.timedMetadata else { return }
            self.metadataContinuation?.yield(items)
        }

        // Failure notification
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                log.error("playback failed: \(error.localizedDescription)")
                self?.handlePlaybackError(error)
            }
        }

        // Stalled notification
        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            log.warning("playback stalled")
            self?.handleStalled()
        }

        // Error log entries (diagnostics)
        errorLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self, let entry = self.playerItem?.errorLog()?.events.last else { return }
            log.warning("AVPlayer error log: domain=\(entry.errorDomain) code=\(entry.errorStatusCode) comment=\(entry.errorComment ?? "-")")
        }
    }

    // MARK: - Status Handling

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            log.debug("playerItem status: readyToPlay")
            reconnectAttempts = 0
        case .failed:
            log.error("playerItem status: failed — \(self.playerItem?.error?.localizedDescription ?? "?")")
            if let error = playerItem?.error {
                handlePlaybackError(error)
            }
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Error / Stall Handling

    private func handlePlaybackError(_ error: Error) {
        if !isNetworkAvailable {
            state = .error(.networkUnavailable)
            wasDisconnectedDuringPlayback = true
            log.warning("error with no network — waiting for network recovery")
            // NWPathMonitor will trigger auto-reconnect when network returns
            return
        }
        attemptReconnect()
    }

    private func handleStalled() {
        if state == .playing {
            state = .buffering
        }

        if !isNetworkAvailable {
            wasDisconnectedDuringPlayback = true
            log.warning("stalled with no network — waiting for recovery")
            return
        }

        // Recreate the stream instead of just calling play()
        attemptReconnect()
    }

    private func attemptReconnect() {
        guard let url = currentURL else { return }

        guard reconnectAttempts < Constants.Audio.maxReconnectAttempts else {
            log.error("reconnect: all \(Constants.Audio.maxReconnectAttempts) attempts exhausted")
            state = .error(.bufferingTimeout)
            wasDisconnectedDuringPlayback = true
            // NWPathMonitor will still auto-retry if network recovers
            return
        }

        reconnectAttempts += 1

        // Exponential backoff: 2, 4, 8, 16, 32, 64, 128 seconds (capped at 60)
        let delay = min(Constants.Audio.reconnectBaseDelay * pow(2.0, Double(reconnectAttempts - 1)), 60.0)
        log.info("reconnect: attempt \(self.reconnectAttempts)/\(Constants.Audio.maxReconnectAttempts) in \(String(format: "%.1f", delay))s")

        state = .buffering

        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Fully recreate player with fresh AVPlayerItem
            let attempts = self.reconnectAttempts
            self.teardownPlayer()
            self.reconnectAttempts = attempts
            self.state = .connecting
            self.setupPlayer(with: url)
            self.startBufferMonitoring()
            self.player?.play()
        }
    }

    // MARK: - Buffer Monitoring

    private func startBufferMonitoring() {
        // Buffer state transitions are handled by KVO observers
        // (isPlaybackBufferEmpty, isPlaybackLikelyToKeepUp).
        // No periodic polling needed.
    }

    private func stopBufferMonitoring() {
        // Reserved for future use (e.g., progress indicator).
    }

    // MARK: - Teardown

    /// Teardown player only (preserves currentURL for reconnection).
    private func teardownPlayer() {
        reconnectTask?.cancel()
        reconnectTask = nil
        stopBufferMonitoring()

        statusObservation?.invalidate()
        statusObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        likelyToKeepUpObservation?.invalidate()
        likelyToKeepUpObservation = nil
        metadataObservation?.invalidate()
        metadataObservation = nil

        if let obs = stalledObserver { NotificationCenter.default.removeObserver(obs) }
        stalledObserver = nil
        if let obs = failedObserver { NotificationCenter.default.removeObserver(obs) }
        failedObserver = nil
        if let obs = errorLogObserver { NotificationCenter.default.removeObserver(obs) }
        errorLogObserver = nil

        player?.pause()
        player = nil
        playerItem = nil
    }

    /// Full teardown including URL (user-initiated stop).
    private func teardown() {
        teardownPlayer()
        currentURL = nil
        wasDisconnectedDuringPlayback = false
        reconnectAttempts = 0
    }
}

// MARK: - NWInterface.InterfaceType debug helper

extension NWInterface.InterfaceType {
    var debugDescription: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "ethernet"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
