import UIKit
import os

private let log = Logger(subsystem: "fm.oton", category: "Artwork")

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
            log.info("loadArtwork: no URL for \"\(track.title)\" → defaultArtwork")
            return makeDefault()
        }

        log.info("loadArtwork: \"\(track.title)\" url=\(urlString)")

        // Retry loop with progressive back-off
        for attempt in 0..<Constants.Audio.maxArtworkRetries {
            if attempt > 0 {
                log.debug("loadArtwork: retry #\(attempt) for \"\(track.title)\"")
                let delay = UInt64(attempt) * 2 * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let image = try await networkClient.fetchImage(from: url, cacheBusting: true)
                let type = classifyArtwork(urlString: urlString, image: image)
                let averageColor = image.averageColor
                log.info("loadArtwork: \"\(track.title)\" → \(String(describing: type)), size=\(Int(image.size.width))x\(Int(image.size.height))")
                return ArtworkResult(image: image, type: type, averageColor: averageColor)
            } catch {
                log.warning("loadArtwork: attempt \(attempt) failed: \(error.localizedDescription)")
                continue
            }
        }

        log.warning("loadArtwork: all retries failed for \"\(track.title)\" → defaultArtwork")
        return makeDefault()
    }

    func loadStationLogo() -> ArtworkResult {
        log.debug("loadStationLogo")
        let image = UIImage(named: "stationLogo") ?? _defaultArtwork
        return ArtworkResult(image: image, type: .stationLogo, averageColor: image.averageColor)
    }

    // MARK: - Classification

    private func classifyArtwork(urlString: String, image: UIImage) -> ArtworkType {
        let lowered = urlString.lowercased()
        if lowered.contains("station_logos") {
            log.debug("classify: station_logos in URL → stationLogo")
            return .stationLogo
        }
        if lowered.contains(Config.radioStationID) {
            log.debug("classify: stationID in URL → stationLogo")
            return .stationLogo
        }
        if lowered.contains("oton") {
            log.debug("classify: 'oton' in URL → stationLogo")
            return .stationLogo
        }

        // Album artwork is always roughly square. Station logos / banners are wide.
        // If aspect ratio > 1.5, treat as station logo.
        let w = image.size.width
        let h = image.size.height
        if h > 0 && w / h > 1.5 {
            log.debug("classify: wide aspect \(w)/\(h)=\(w/h) → stationLogo")
            return .stationLogo
        }

        log.debug("classify: → realArtwork")
        return .realArtwork
    }

    private func makeDefault() -> ArtworkResult {
        ArtworkResult(image: _defaultArtwork, type: .defaultArtwork, averageColor: _defaultArtwork.averageColor)
    }
}
