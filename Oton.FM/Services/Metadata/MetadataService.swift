import AVFoundation

/// Production metadata service: extracts track titles from ICY metadata
/// and fetches current track info from the radio.co status API.
final class MetadataService: MetadataServiceProtocol, @unchecked Sendable {

    private let networkClient: any NetworkClientProtocol

    init(networkClient: any NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    // MARK: - MetadataServiceProtocol

    func trackTitle(from metadata: [AVMetadataItem]) -> String? {
        for item in metadata {
            // Prefer the common title identifier
            if item.identifier == .commonIdentifierTitle, let title = item.stringValue, !title.isEmpty {
                return title
            }
            // Fallback: treat the raw value as a string
            if let title = item.value as? String, !title.isEmpty {
                return title
            }
        }
        return nil
    }

    func fetchCurrentTrack() async throws -> TrackInfo {
        guard let url = URL(string: Config.radioStatusURL) else {
            throw NetworkError.noData
        }
        let response: RadioStatusResponse = try await networkClient.fetch(
            RadioStatusResponse.self,
            from: url,
            cacheBusting: true
        )
        guard let track = response.currentTrack else {
            throw NetworkError.noData
        }
        return track
    }
}
