import SwiftUI

/// Sequentially appearing dots for the "Kholbonuu..." connecting indicator.
/// Cycles through 4 states: 0 hidden -> 1 -> 2 -> 3 visible -> 0 (reset).
struct AnimatedDots: View {
    @State private var showingDots = 0

    private let timer = Timer.publish(
        every: Constants.Animation.dotsInterval,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        HStack(spacing: Constants.Dots.spacing) {
            ForEach(1...Constants.Dots.count, id: \.self) { index in
                Text(".")
                    .opacity(showingDots >= index ? 1 : 0)
                    .animation(.easeIn, value: showingDots)
            }
        }
        .onReceive(timer) { _ in
            showingDots = (showingDots + 1) % Constants.Dots.stateCount
        }
    }
}

/// "Kholbonuu" (Yakut for "Connecting") with animated dots.
struct ConnectingText: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Холбонуу")
                .font(AppFonts.trackTitle)
            AnimatedDots()
                .font(AppFonts.trackTitle)
        }
        .foregroundColor(AppColors.textPrimary)
        .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
    }
}
