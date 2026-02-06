import ActivityKit
import Foundation

/// ActivityKit attributes for the "Now Playing" Live Activity.
/// This file must be included in both the main app target and the widget extension target.
struct NowPlayingAttributes: ActivityAttributes {

    /// Dynamic data that changes during the activity's lifetime.
    struct ContentState: Codable, Hashable {
        /// Current track title (e.g. "Artist - Song Name").
        var trackTitle: String
        /// Whether the stream is currently playing.
        var isPlaying: Bool
        /// JPEG artwork data for the current track (nil = show radio icon).
        var artworkData: Data?
    }
}
