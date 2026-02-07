import SwiftUI

/// Displays the current track title, connecting status, or station name.
struct TrackInfoView: View {
    let isConnecting: Bool
    let isPlaying: Bool
    let trackTitle: String
    let nextTrackTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                if isConnecting {
                    ConnectingText()
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
                        .transition(.blurReplace)
                } else if isPlaying && !trackTitle.isEmpty {
                    TypewriterText(
                        text: trackTitle,
                        font: AppFonts.trackTitle,
                        color: AppColors.textPrimary
                    )
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
                    .id(trackTitle)
                    .transition(.blurReplace)
                } else {
                    Text("OTON FM")
                        .font(AppFonts.trackTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: Constants.Layout.trackInfoHeight, alignment: .leading)
                        .transition(.blurReplace)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Constants.Layout.trackInfoHeight)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: isConnecting)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: trackTitle)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: isPlaying)

            // Always reserve space for the next track line to prevent layout jumps
            MarqueeText(
                text: nextTrackTitle.isEmpty ? " " : "Сотору: \(nextTrackTitle)",
                font: AppFonts.nextTrackSubtitle,
                color: AppColors.textTertiary
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(nextTrackTitle.isEmpty ? 0 : 1)
            .animation(.easeInOut(duration: Constants.Animation.textTransition), value: nextTrackTitle)
        }
        .padding(.horizontal, UIScreen.main.bounds.width * Constants.Layout.horizontalPaddingRatio)
        .offset(y: Constants.Layout.trackInfoOffset)
    }
}

// MARK: - Preference Key

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Marquee Text

/// Horizontally scrolling text when content exceeds available width.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private let gap: CGFloat = 60
    private let speed: CGFloat = 25.0

    private var needsScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: gap) {
                marqueeLabel
                if needsScroll {
                    marqueeLabel
                }
            }
            .offset(x: offset)
            .onAppear {
                containerWidth = geo.size.width
                beginScrolling()
            }
            .onChange(of: text) { _, _ in
                resetAndScroll()
            }
        }
        .frame(height: 18)
        .clipped()
        .overlay {
            Text(text)
                .font(font)
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: TextWidthKey.self, value: proxy.size.width)
                    }
                )
        }
        .onPreferenceChange(TextWidthKey.self) { width in
            let changed = textWidth != width
            textWidth = width
            if changed { resetAndScroll() }
        }
    }

    private var marqueeLabel: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func beginScrolling() {
        guard needsScroll else { return }
        let distance = textWidth + gap
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard needsScroll else { return }
            withAnimation(.linear(duration: distance / speed).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }

    private func resetAndScroll() {
        withAnimation(nil) { offset = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            beginScrolling()
        }
    }
}

// MARK: - Typewriter Text

/// Reveals text character by character with a typewriter effect.
private struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var visibleCount = 0
    @State private var timer: Timer?

    private let charDelay: TimeInterval = 0.04

    var body: some View {
        Text(text.prefix(visibleCount) + (visibleCount < text.count ? " " : ""))
            .font(font)
            .foregroundColor(color)
            .onAppear { startTyping() }
            .onDisappear { stopTimer() }
            .onChange(of: text) { _, _ in restartTyping() }
    }

    private func startTyping() {
        visibleCount = 0
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: charDelay, repeats: true) { t in
            if visibleCount < text.count {
                visibleCount += 1
            } else {
                t.invalidate()
            }
        }
    }

    private func restartTyping() {
        stopTimer()
        visibleCount = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startTyping()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

