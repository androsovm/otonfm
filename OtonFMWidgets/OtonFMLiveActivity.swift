import ActivityKit
import SwiftUI
import WidgetKit

/// Widget that provides Live Activity views for Lock Screen and Dynamic Island.
struct OtonFMLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / StandBy Live Activity view
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long press on Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    artworkOrIcon(data: context.state.artworkData, size: 32)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.trackTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Text("Oton FM \u{2014} Live")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(.trailing, 4)
                }
            } compactLeading: {
                // Compact leading (left pill)
                artworkOrIcon(data: context.state.artworkData, size: 20)
            } compactTrailing: {
                // Compact trailing (right pill) -- play/pause icon
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
            } minimal: {
                // Minimal view (when competing with another Live Activity)
                artworkOrIcon(data: context.state.artworkData, size: 20)
            }
        }
    }

    // MARK: - Artwork or Radio Icon

    /// Shows the track artwork if available, otherwise a styled radio icon.
    @ViewBuilder
    private func artworkOrIcon(data: Data?, size: CGFloat) -> some View {
        if let data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color(red: 0.81, green: 0.17, blue: 0.17))
                    .frame(width: size, height: size)
                Image(systemName: "radio.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        HStack(spacing: 12) {
            // Artwork or radio icon
            artworkOrIcon(data: context.state.artworkData, size: 44)

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.trackTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Oton FM")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Play/pause indicator
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.81, green: 0.17, blue: 0.17), Color(red: 0.07, green: 0.07, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
