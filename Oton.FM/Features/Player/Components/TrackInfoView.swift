import SwiftUI

/// Displays the current track title, connecting status, or station name.
struct TrackInfoView: View {
    let isConnecting: Bool
    let isPlaying: Bool
    let trackTitle: String

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                if isConnecting {
                    ConnectingText()
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if isPlaying && !trackTitle.isEmpty {
                    Text(trackTitle)
                        .id(trackTitle)
                        .font(AppFonts.trackTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("OTON FM")
                        .font(AppFonts.trackTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: isConnecting)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: trackTitle)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: isPlaying)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, UIScreen.main.bounds.width * Constants.Layout.horizontalPaddingRatio)
        .offset(y: Constants.Layout.trackInfoOffset)
    }
}
