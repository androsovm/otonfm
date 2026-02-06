import Foundation

/// UI-level display state derived from service states.
enum PlayerDisplayState: Equatable {
    /// No playback activity.
    case idle
    /// Establishing connection to the stream.
    case connecting
    /// Actively playing audio.
    case playing
    /// Buffer ran empty during playback.
    case buffering
    /// User-initiated pause.
    case paused
    /// An error occurred.
    case error(AudioError)
}
