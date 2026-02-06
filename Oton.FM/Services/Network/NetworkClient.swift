import UIKit

/// Production HTTP client with shared URLSession, cache-busting, and typed decoding.
final class NetworkClient: NetworkClientProtocol, @unchecked Sendable {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = Constants.Audio.apiTimeout
        config.timeoutIntervalForResource = Constants.Audio.apiTimeout
        self.session = URLSession(configuration: config)
    }

    func fetch<T: Decodable>(_ type: T.Type, from url: URL, cacheBusting: Bool) async throws -> T {
        let request = makeRequest(for: url, cacheBusting: cacheBusting)
        let (data, response) = try await perform(request)
        try validate(response)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    func fetchImage(from url: URL, cacheBusting: Bool) async throws -> UIImage {
        var request = makeRequest(for: url, cacheBusting: cacheBusting)
        if cacheBusting {
            request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }

        let (data, response) = try await perform(request)
        try validate(response)

        guard !data.isEmpty, let image = UIImage(data: data) else {
            throw NetworkError.invalidImageData
        }
        return image
    }

    // MARK: - Helpers

    private func makeRequest(for url: URL, cacheBusting: Bool) -> URLRequest {
        let finalURL: URL
        if cacheBusting {
            let separator = url.absoluteString.contains("?") ? "&" : "?"
            let busted = "\(url.absoluteString)\(separator)nocache=\(Date().timeIntervalSince1970)"
            finalURL = URL(string: busted) ?? url
        } else {
            finalURL = url
        }
        var request = URLRequest(url: finalURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw NetworkError.cancelled
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.noData
            }
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.httpError(statusCode: http.statusCode)
        }
    }
}
