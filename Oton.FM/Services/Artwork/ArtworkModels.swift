import UIKit

/// Result of an artwork loading operation, bundling the image with its classification.
struct ArtworkResult: Sendable {
    let image: UIImage
    let type: ArtworkType
    let averageColor: UIColor?
}

/// Classification of a loaded artwork image.
enum ArtworkType: Sendable {
    /// A real album/track artwork loaded from the API.
    case realArtwork
    /// The station logo (detected by URL pattern).
    case stationLogo
    /// The bundled default artwork from app assets.
    case defaultArtwork
}
