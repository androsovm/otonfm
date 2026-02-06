import AVFoundation

/// Manages AVPlayer lifecycle, audio session, buffering, and reconnection.
/// Emits state changes and timed metadata through async streams.
protocol AudioEngineProtocol: Sendable {
    /// Current playback state.
    var state: AudioState { get }

    /// Async stream of state transitions.
    var stateStream: AsyncStream<AudioState> { get }

    /// Async stream of timed metadata items from the ICY stream.
    var metadataStream: AsyncStream<[AVMetadataItem]> { get }

    /// Start playback from the given stream URL.
    /// Transitions: idle/paused/error -> connecting -> playing.
    func play(url: URL) async

    /// Pause playback. Transitions: playing -> paused.
    func pause()

    /// Stop playback and release resources. Transitions: any -> idle.
    func stop()
}
