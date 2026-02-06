import Foundation

/// Application configuration: URLs, station ID, and API keys.
enum Config {
    /// RevenueCat API key for subscription management.
    /// NOTE: In production, load from a secure source (e.g., xcconfig, keychain).
    static let revenueCatAPIKey = "appl_SUEUYjngtLhXGzXaOeHnovfAmfS"

    /// Live audio stream URL (radio.co platform).
    static let radioStreamURL = "https://s4.radio.co/s696f24a77/listen"

    /// Status API endpoint for current track metadata.
    static let radioStatusURL = "https://public.radio.co/stations/s696f24a77/status"

    /// Next track API endpoint.
    static let radioNextTrackURL = "https://public.radio.co/stations/s696f24a77/next"

    /// Radio.co station identifier.
    static let radioStationID = "s696f24a77"
}
