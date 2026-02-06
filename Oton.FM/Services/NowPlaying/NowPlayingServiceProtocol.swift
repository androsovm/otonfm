import UIKit

/// Manages MPNowPlayingInfoCenter and MPRemoteCommandCenter.
protocol NowPlayingServiceProtocol {
    /// Register play/pause remote command handlers. Call once at setup.
    func configure(playAction: @escaping () -> Void, pauseAction: @escaping () -> Void)

    /// Update the Now Playing information displayed on the lock screen and Control Center.
    func update(title: String, artist: String, artwork: UIImage?, isLiveStream: Bool)

    /// Clear all Now Playing information.
    func clear()
}
