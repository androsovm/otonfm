import Foundation

/// Represents a single track from the radio.co status API.
struct TrackInfo: Codable, Equatable, Sendable {
    let title: String
    let artworkUrl: String?
    let artworkUrlLarge: String?

    /// Best available artwork URL (prefer large).
    var bestArtworkUrl: String? {
        artworkUrlLarge ?? artworkUrl
    }

    enum CodingKeys: String, CodingKey {
        case title
        case artworkUrl = "artwork_url"
        case artworkUrlLarge = "artwork_url_large"
    }
}

/// Top-level response from the radio.co status endpoint.
struct RadioStatusResponse: Codable, Sendable {
    let currentTrack: TrackInfo?

    enum CodingKeys: String, CodingKey {
        case currentTrack = "current_track"
    }
}
