import Foundation
import AVFoundation
import Combine
import MediaPlayer

final class AudioService: NSObject, AudioServiceProtocol {
    // MARK: - Published Properties
    @Published private var _isPlaying: Bool = false
    @Published private var _isBuffering: Bool = false
    @Published private var _playerState: PlayerState = .stopped
    @Published private var _bufferProgress: Float = 0.0
    
    // MARK: - Public Publishers
    var isPlaying: AnyPublisher<Bool, Never> {
        $_isPlaying.eraseToAnyPublisher()
    }
    
    var isBuffering: AnyPublisher<Bool, Never> {
        $_isBuffering.eraseToAnyPublisher()
    }
    
    var playerState: AnyPublisher<PlayerState, Never> {
        $_playerState.eraseToAnyPublisher()
    }
    
    var bufferProgress: AnyPublisher<Float, Never> {
        $_bufferProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var bufferCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Delegate
    weak var delegate: AudioServiceDelegate?
    
    // Buffer configuration
    private let defaultBufferDuration: TimeInterval = 10.0
    private let bufferCheckInterval: TimeInterval = 0.5
    private let reconnectDelay: TimeInterval = 2.0
    private let maxReconnectAttempts = 3
    private var reconnectAttempts = 0
    
    // MARK: - Initialization
    override init() {
        super.init()
        configureAudioSession()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    func play(url: URL) {
        stop()
        
        _playerState = .connecting
        _isBuffering = true
        reconnectAttempts = 0
        
        setupPlayer(with: url)
        startBufferMonitoring()
        
        player?.play()
        _isPlaying = true
    }
    
    func pause() {
        player?.pause()
        _isPlaying = false
        _playerState = .paused
        stopBufferMonitoring()
    }
    
    func stop() {
        stopBufferMonitoring()
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Remove metadata observer
        playerItem?.removeObserver(self, forKeyPath: "timedMetadata")
        
        player?.pause()
        player = nil
        playerItem = nil
        
        _isPlaying = false
        _isBuffering = false
        _playerState = .stopped
        _bufferProgress = 0.0
    }
    
    func setBufferSize(_ seconds: TimeInterval) {
        // This would require custom AVAssetResourceLoader implementation
        // For now, we'll use the default system buffering
    }
    
    // MARK: - Private Methods
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupPlayer(with url: URL) {
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Configure buffer
        player?.automaticallyWaitsToMinimizeStalling = true
        playerItem?.preferredForwardBufferDuration = defaultBufferDuration
        
        // Add observers
        addPlayerObservers()
        
        // Add metadata observer
        playerItem?.addObserver(self, forKeyPath: "timedMetadata", options: [.new, .initial], context: nil)
    }
    
    private func addPlayerObservers() {
        guard let playerItem = playerItem else { return }
        
        // Status observer
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                self?.handlePlayerItemStatusChange(status)
            }
            .store(in: &cancellables)
        
        // Buffer observer
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .sink { [weak self] isEmpty in
                if isEmpty {
                    self?._isBuffering = true
                }
            }
            .store(in: &cancellables)
        
        // Playback likely to keep up observer
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] likelyToKeepUp in
                if likelyToKeepUp {
                    self?._isBuffering = false
                    if self?._playerState == .connecting {
                        self?._playerState = .playing
                    }
                }
            }
            .store(in: &cancellables)
        
        // Error observer
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self?.handlePlaybackError(error)
                }
            }
            .store(in: &cancellables)
        
        // Stalled observer
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled)
            .sink { [weak self] _ in
                self?.handlePlaybackStalled()
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            print("Player ready to play")
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
    
    private func handlePlaybackError(_ error: Error) {
        print("Playback error: \(error.localizedDescription)")
        
        _playerState = .error(RadioError.streamUnavailable)
        
        // Attempt to reconnect
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            print("Attempting to reconnect... (attempt \(reconnectAttempts))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
                guard let self = self,
                      let url = self.playerItem?.asset.value(forKey: "URL") as? URL else { return }
                self.play(url: url)
            }
        } else {
            _playerState = .error(RadioError.bufferingTimeout)
        }
    }
    
    private func handlePlaybackStalled() {
        print("Playback stalled")
        _isBuffering = true
        
        // Try to restart playback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self,
                  self._isPlaying,
                  let player = self.player else { return }
            
            player.play()
        }
    }
    
    // MARK: - Buffer Monitoring
    private func startBufferMonitoring() {
        stopBufferMonitoring()
        
        bufferCheckTimer = Timer.scheduledTimer(withTimeInterval: bufferCheckInterval, repeats: true) { [weak self] _ in
            self?.updateBufferProgress()
        }
    }
    
    private func stopBufferMonitoring() {
        bufferCheckTimer?.invalidate()
        bufferCheckTimer = nil
    }
    
    private func updateBufferProgress() {
        guard let playerItem = playerItem else { return }
        
        let timeRanges = playerItem.loadedTimeRanges
        guard let timeRange = timeRanges.first?.timeRangeValue else { return }
        
        let startTime = CMTimeGetSeconds(timeRange.start)
        let duration = CMTimeGetSeconds(timeRange.duration)
        let currentTime = CMTimeGetSeconds(playerItem.currentTime())
        
        if duration > 0 {
            let bufferedTime = startTime + duration
            let progress = Float(min((bufferedTime - currentTime) / defaultBufferDuration, 1.0))
            _bufferProgress = max(0, progress)
        }
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timedMetadata" {
            // Получаем метаданные напрямую из playerItem
            if let playerItem = playerItem,
               let metadataItems = playerItem.timedMetadata {
                print("📊 AudioService received metadata: \(metadataItems.count) items")
                delegate?.audioService(self, didUpdateMetadata: metadataItems)
            }
        }
    }
}