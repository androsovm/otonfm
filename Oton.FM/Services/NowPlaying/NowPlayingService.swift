import UIKit
import MediaPlayer

/// Production Now Playing service managing the lock screen / Control Center info.
final class NowPlayingService: NowPlayingServiceProtocol {

    private var playTarget: Any?
    private var pauseTarget: Any?

    func configure(playAction: @escaping () -> Void, pauseAction: @escaping () -> Void) {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Remove previous handlers to avoid stacking duplicates
        if let target = playTarget { commandCenter.playCommand.removeTarget(target) }
        if let target = pauseTarget { commandCenter.pauseCommand.removeTarget(target) }

        commandCenter.playCommand.isEnabled = true
        playTarget = commandCenter.playCommand.addTarget { _ in
            playAction()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        pauseTarget = commandCenter.pauseCommand.addTarget { _ in
            pauseAction()
            return .success
        }
    }

    func update(title: String, artist: String, artwork: UIImage?, isLiveStream: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream

        if let image = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

/// Stub for compilation before Task #11.
final class StubNowPlayingService: NowPlayingServiceProtocol {
    func configure(playAction: @escaping () -> Void, pauseAction: @escaping () -> Void) {}
    func update(title: String, artist: String, artwork: UIImage?, isLiveStream: Bool) {}
    func clear() {}
}
