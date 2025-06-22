import Foundation
import AVFoundation
import Combine

// Простая обертка для постепенной миграции RadioPlayer на использование AudioService
class AudioServiceWrapper {
    private let audioService: AudioService
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks для интеграции с существующим RadioPlayer
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onBufferingStateChanged: ((Bool) -> Void)?
    var onConnectingStateChanged: ((Bool) -> Void)?
    var onMetadataReceived: (([AVMetadataItem]) -> Void)?
    var onError: ((RadioError) -> Void)?
    
    init() {
        self.audioService = AudioService()
        setupBindings()
    }
    
    private func setupBindings() {
        // Подписываемся на изменения состояния
        audioService.isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.onPlaybackStateChanged?(isPlaying)
            }
            .store(in: &cancellables)
        
        audioService.isBuffering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isBuffering in
                self?.onBufferingStateChanged?(isBuffering)
            }
            .store(in: &cancellables)
        
        audioService.playerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .error(let radioError) = state {
                    self?.onError?(radioError)
                }
                // Обновляем состояние подключения
                self?.onConnectingStateChanged?(state == .connecting)
            }
            .store(in: &cancellables)
        
        // Делегат для метаданных
        audioService.delegate = self
    }
    
    func play(url: URL) {
        audioService.play(url: url)
    }
    
    func pause() {
        audioService.pause()
    }
    
    func stop() {
        audioService.stop()
    }
}

// MARK: - AudioServiceDelegate
extension AudioServiceWrapper: AudioServiceDelegate {
    func audioService(_ service: AudioServiceProtocol, didUpdateMetadata metadata: [AVMetadataItem]) {
        print("🎵 AudioServiceWrapper received metadata: \(metadata.count) items")
        for item in metadata {
            if let value = item.value {
                print("🎵 Metadata item: \(item.identifier?.rawValue ?? "unknown") = \(value)")
            }
            if let stringValue = item.stringValue {
                print("🎵 String value: \(stringValue)")
            }
        }
        onMetadataReceived?(metadata)
    }
}