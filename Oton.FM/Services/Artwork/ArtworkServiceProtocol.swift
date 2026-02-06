import UIKit

/// Loads, caches, and classifies track artwork images.
protocol ArtworkServiceProtocol: Sendable {
    /// Load artwork for the given track from the status API.
    /// Returns the image, its type, and precomputed average color.
    func loadArtwork(for track: TrackInfo) async -> ArtworkResult

    /// Load the station logo from bundled assets.
    func loadStationLogo() -> ArtworkResult

    /// The bundled default artwork image.
    var defaultArtwork: UIImage { get }
}
