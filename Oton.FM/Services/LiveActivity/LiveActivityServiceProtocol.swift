import Foundation

/// Manages the Live Activity lifecycle for "Now Playing" on Lock Screen and Dynamic Island.
protocol LiveActivityServiceProtocol {
    /// Start a new Live Activity with the given track title.
    func start(trackTitle: String, isPlaying: Bool, artworkData: Data?)

    /// Update the current Live Activity with new track info.
    func update(trackTitle: String, isPlaying: Bool, artworkData: Data?)

    /// End the current Live Activity (e.g. when playback stops).
    func end()
}
