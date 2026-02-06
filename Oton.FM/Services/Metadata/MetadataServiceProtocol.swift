import AVFoundation

/// Extracts track metadata from timed metadata and the status API.
protocol MetadataServiceProtocol: Sendable {
    /// Extract the track title from AVPlayer timed metadata items.
    func trackTitle(from metadata: [AVMetadataItem]) -> String?

    /// Fetch current track info from the radio.co status API.
    func fetchCurrentTrack() async throws -> TrackInfo

    /// Fetch next track info from the radio.co next track API.
    func fetchNextTrack() async throws -> TrackInfo
}
