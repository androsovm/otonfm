import AVFoundation

/// Production audio engine managing AVPlayer, audio session, buffering, and reconnection.
/// Uses AsyncStream for state and metadata delivery instead of Combine/callbacks.
final class AudioEngine: NSObject, AudioEngineProtocol, @unchecked Sendable {

    // MARK: - Public state

    private(set) var state: AudioState = .idle {
        didSet {
            guard state != oldValue else { return }
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
    private var bufferCheckTimer: Timer?

    // MARK: - KVO tokens

    private var statusObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var stalledObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
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
    }

    deinit {
        teardown()
        stateContinuation?.finish()
        metadataContinuation?.finish()
    }

    // MARK: - AudioEngineProtocol

    func play(url: URL) async {
        teardown()

        currentURL = url
        reconnectAttempts = 0
        state = .connecting

        setupPlayer(with: url)
        startBufferMonitoring()
        player?.play()
    }

    func pause() {
        player?.pause()
        stopBufferMonitoring()
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
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AudioEngine: failed to configure audio session: \(error)")
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
            if state == .playing || state == .buffering {
                player?.pause()
                state = .paused
            }
        case .ended:
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

        if reason == .oldDeviceUnavailable {
            // Headphones disconnected
            if state == .playing || state == .buffering {
                pause()
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
                    self.state = .playing
                }
            }
        }

        // Timed metadata
        item.addObserver(self, forKeyPath: "timedMetadata", options: [.new], context: nil)

        // Failure notification
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                self?.handlePlaybackError(error)
            }
        }

        // Stalled notification
        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleStalled()
        }
    }

    // MARK: - KVO override for timed metadata

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "timedMetadata", let items = playerItem?.timedMetadata {
            metadataContinuation?.yield(items)
        }
    }

    // MARK: - Status Handling

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            reconnectAttempts = 0
        case .failed:
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
        state = .error(.streamUnavailable)
        attemptReconnect()
    }

    private func handleStalled() {
        if state == .playing {
            state = .buffering
        }
        // Retry playback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Audio.reconnectDelay) { [weak self] in
            guard let self, self.state == .buffering else { return }
            self.player?.play()
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < Constants.Audio.maxReconnectAttempts else {
            state = .error(.bufferingTimeout)
            return
        }
        reconnectAttempts += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Audio.reconnectDelay) { [weak self] in
            guard let self, let url = self.currentURL else { return }
            Task { @MainActor in
                await self.play(url: url)
            }
        }
    }

    // MARK: - Buffer Monitoring

    private func startBufferMonitoring() {
        stopBufferMonitoring()
        bufferCheckTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Audio.bufferCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkBuffer()
        }
    }

    private func stopBufferMonitoring() {
        bufferCheckTimer?.invalidate()
        bufferCheckTimer = nil
    }

    private func checkBuffer() {
        // Buffer monitoring provides data for potential future use (progress indicator).
        // The actual buffering/playing transitions are handled by KVO observers.
    }

    // MARK: - Teardown

    private func teardown() {
        stopBufferMonitoring()

        statusObservation?.invalidate()
        statusObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        likelyToKeepUpObservation?.invalidate()
        likelyToKeepUpObservation = nil

        if let obs = stalledObserver { NotificationCenter.default.removeObserver(obs) }
        stalledObserver = nil
        if let obs = failedObserver { NotificationCenter.default.removeObserver(obs) }
        failedObserver = nil

        if playerItem != nil {
            playerItem?.removeObserver(self, forKeyPath: "timedMetadata")
        }

        player?.pause()
        player = nil
        playerItem = nil
        currentURL = nil
    }
}
