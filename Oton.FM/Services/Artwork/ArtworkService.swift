import UIKit

/// Production artwork service: loads, retries, classifies, and caches average color.
final class ArtworkService: ArtworkServiceProtocol, @unchecked Sendable {

    private let networkClient: any NetworkClientProtocol
    private let _defaultArtwork: UIImage

    var defaultArtwork: UIImage { _defaultArtwork }

    init(networkClient: any NetworkClientProtocol) {
        self.networkClient = networkClient
        self._defaultArtwork = UIImage(named: "defaultArtwork") ?? UIImage()
    }

    // MARK: - ArtworkServiceProtocol

    func loadArtwork(for track: TrackInfo) async -> ArtworkResult {
        guard let urlString = track.bestArtworkUrl,
              let url = URL(string: urlString) else {
            return makeDefault()
        }

        // Retry loop with progressive back-off
        for attempt in 0..<Constants.Audio.maxArtworkRetries {
            if attempt > 0 {
                let delay = UInt64(attempt) * 2 * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let image = try await networkClient.fetchImage(from: url, cacheBusting: true)
                let type = classifyArtwork(urlString: urlString, image: image)
                let averageColor = image.averageColor
                return ArtworkResult(image: image, type: type, averageColor: averageColor)
            } catch {
                continue
            }
        }

        return makeDefault()
    }

    func loadStationLogo() -> ArtworkResult {
        let image = UIImage(named: "stationLogo") ?? _defaultArtwork
        return ArtworkResult(image: image, type: .stationLogo, averageColor: image.averageColor)
    }

    // MARK: - Classification

    private func classifyArtwork(urlString: String, image: UIImage) -> ArtworkType {
        let lowered = urlString.lowercased()
        if lowered.contains("station_logos")
            || lowered.contains(Config.radioStationID)
            || lowered.contains("oton") {
            return .stationLogo
        }

        // Album artwork is always roughly square. Station logos / banners are wide.
        // If aspect ratio > 1.5, treat as station logo.
        let w = image.size.width
        let h = image.size.height
        if h > 0 && w / h > 1.5 {
            return .stationLogo
        }

        return .realArtwork
    }

    private func makeDefault() -> ArtworkResult {
        ArtworkResult(image: _defaultArtwork, type: .defaultArtwork, averageColor: _defaultArtwork.averageColor)
    }
}
