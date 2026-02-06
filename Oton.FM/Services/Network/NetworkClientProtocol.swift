import UIKit

/// HTTP networking layer with shared URLSession, cache-busting, and typed decoding.
protocol NetworkClientProtocol: Sendable {
    /// Fetch and decode a Decodable type from the given URL.
    /// When `cacheBusting` is true, appends a `nocache` query parameter.
    func fetch<T: Decodable>(_ type: T.Type, from url: URL, cacheBusting: Bool) async throws -> T

    /// Download an image from the given URL.
    /// When `cacheBusting` is true, appends a `nocache` query parameter and `Cache-Control: no-cache` header.
    func fetchImage(from url: URL, cacheBusting: Bool) async throws -> UIImage
}

/// Network-layer errors.
enum NetworkError: LocalizedError, Sendable {
    case noData
    case decodingFailed
    case httpError(statusCode: Int)
    case timeout
    case cancelled
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received"
        case .decodingFailed:
            return "Failed to decode response"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}
