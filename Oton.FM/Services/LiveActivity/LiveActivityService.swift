import ActivityKit
import Foundation

/// Production Live Activity service using ActivityKit.
/// Manages a single NowPlayingAttributes Live Activity.
final class LiveActivityService: LiveActivityServiceProtocol {

    private var currentActivity: Activity<NowPlayingAttributes>?

    func start(trackTitle: String, isPlaying: Bool, artworkData: Data?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = NowPlayingAttributes.ContentState(
            trackTitle: trackTitle,
            isPlaying: isPlaying,
            artworkData: artworkData
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let activity = try Activity<NowPlayingAttributes>.request(
                attributes: NowPlayingAttributes(),
                content: content,
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("[LiveActivityService] Failed to start activity: \(error)")
        }
    }

    func update(trackTitle: String, isPlaying: Bool, artworkData: Data?) {
        guard let activity = currentActivity else {
            start(trackTitle: trackTitle, isPlaying: isPlaying, artworkData: artworkData)
            return
        }

        let state = NowPlayingAttributes.ContentState(
            trackTitle: trackTitle,
            isPlaying: isPlaying,
            artworkData: artworkData
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)
        }
    }

    func end() {
        guard let activity = currentActivity else { return }

        let state = NowPlayingAttributes.ContentState(
            trackTitle: "",
            isPlaying: false,
            artworkData: nil
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}

/// Stub for testing / compilation without ActivityKit dependency.
final class StubLiveActivityService: LiveActivityServiceProtocol {
    func start(trackTitle: String, isPlaying: Bool, artworkData: Data?) {}
    func update(trackTitle: String, isPlaying: Bool, artworkData: Data?) {}
    func end() {}
}
