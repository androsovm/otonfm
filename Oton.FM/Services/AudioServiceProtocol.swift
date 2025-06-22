import Foundation
import Combine
import AVFoundation

protocol AudioServiceDelegate: AnyObject {
    func audioService(_ service: AudioServiceProtocol, didUpdateMetadata metadata: [AVMetadataItem])
}

protocol AudioServiceProtocol {
    var isPlaying: AnyPublisher<Bool, Never> { get }
    var isBuffering: AnyPublisher<Bool, Never> { get }
    var playerState: AnyPublisher<PlayerState, Never> { get }
    var bufferProgress: AnyPublisher<Float, Never> { get }
    
    var delegate: AudioServiceDelegate? { get set }
    
    func play(url: URL)
    func pause()
    func stop()
    func setBufferSize(_ seconds: TimeInterval)
}