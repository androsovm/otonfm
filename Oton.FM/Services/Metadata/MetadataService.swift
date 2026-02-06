import AVFoundation
import os

private let log = Logger(subsystem: "fm.oton", category: "Metadata")

/// Production metadata service: extracts track titles from ICY metadata
/// and fetches current track info from the radio.co status API.
final class MetadataService: MetadataServiceProtocol, @unchecked Sendable {

    private let networkClient: any NetworkClientProtocol

    init(networkClient: any NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    // MARK: - MetadataServiceProtocol

    func trackTitle(from metadata: [AVMetadataItem]) -> String? {
        log.debug("ICY metadata items: \(metadata.count)")
        for item in metadata {
            let raw = (item.stringValue ?? item.value as? String) ?? "<nil>"
            log.debug("  item id=\(item.identifier?.rawValue ?? "?") raw=\"\(raw)\"")

            // Prefer the common title identifier
            if item.identifier == .commonIdentifierTitle, let title = item.stringValue {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidTitle(trimmed) {
                    log.info("ICY title (commonId): \"\(trimmed)\"")
                    return trimmed
                }
                log.debug("ICY title rejected (commonId): \"\(trimmed)\"")
            }
            // Fallback: treat the raw value as a string
            if let title = item.value as? String {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidTitle(trimmed) {
                    log.info("ICY title (fallback): \"\(trimmed)\"")
                    return trimmed
                }
                log.debug("ICY title rejected (fallback): \"\(trimmed)\"")
            }
        }
        log.warning("ICY metadata: no valid title found")
        return nil
    }

    /// Filter out empty or separator-only titles from ICY metadata.
    private func isValidTitle(_ title: String) -> Bool {
        !title.isEmpty && title != "-"
    }

    func fetchCurrentTrack() async throws -> TrackInfo {
        guard let url = URL(string: Config.radioStatusURL) else {
            log.error("fetchCurrentTrack: invalid URL")
            throw NetworkError.noData
        }
        log.debug("fetchCurrentTrack: requesting...")
        let response: RadioStatusResponse = try await networkClient.fetch(
            RadioStatusResponse.self,
            from: url,
            cacheBusting: true
        )
        guard let track = response.currentTrack else {
            log.warning("fetchCurrentTrack: currentTrack is nil")
            throw NetworkError.noData
        }
        log.info("fetchCurrentTrack: \"\(track.title)\" artwork=\(track.bestArtworkUrl ?? "nil")")
        return track
    }

    func fetchNextTrack() async throws -> TrackInfo {
        guard let url = URL(string: Config.radioNextTrackURL) else {
            log.error("fetchNextTrack: invalid URL")
            throw NetworkError.noData
        }
        log.debug("fetchNextTrack: requesting...")
        let response: NextTrackResponse = try await networkClient.fetch(
            NextTrackResponse.self,
            from: url,
            cacheBusting: true
        )
        guard let track = response.nextTrack, !track.title.isEmpty else {
            log.warning("fetchNextTrack: nextTrack is nil or empty")
            throw NetworkError.noData
        }
        log.info("fetchNextTrack: \"\(track.title)\"")
        return track
    }
}
