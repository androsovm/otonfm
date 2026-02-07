import SwiftUI

/// Banner displayed on the main player screen showing the current admin status message.
/// Long text scrolls horizontally with a marquee effect.
struct AdminStatusBanner: View {
    let status: AdminStatus

    @State private var appeared = false
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var needsMarquee: Bool {
        textWidth > containerWidth
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.type == .urgent ? "exclamationmark.triangle.fill" : "megaphone.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.accentPrimary)
                .flexibleFrame(width: 16)

            marqueeText
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Constants.Layout.giftPaddingV)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.25)))
                .overlay(Capsule().strokeBorder(AppColors.accentPrimary.opacity(0.3), lineWidth: 0.5))
        }
        .clipShape(Capsule())
        .offset(y: appeared ? 0 : -10)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    // MARK: - Marquee

    @ViewBuilder
    private var marqueeText: some View {
        let label = Text(status.text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColors.textPrimary.opacity(0.9))
            .lineLimit(1)
            .fixedSize()

        GeometryReader { geo in
            let cw = geo.size.width
            label
                .background(GeometryReader { textGeo in
                    Color.clear
                        .onAppear {
                            containerWidth = cw
                            textWidth = textGeo.size.width
                            if needsMarquee {
                                startMarquee()
                            }
                        }
                })
                .offset(x: offset)
        }
        .frame(height: 18)
        .clipped()
    }

    private func startMarquee() {
        let overflow = textWidth - containerWidth
        guard overflow > 0 else { return }

        // Pause at start, scroll left, pause at end, scroll back
        let scrollDuration = Double(overflow) / 30.0 // ~30pt per second

        withAnimation(nil) { offset = 0 }

        Task { @MainActor in
            while !Task.isCancelled {
                // Pause at start
                try? await Task.sleep(for: .seconds(2.0))
                // Scroll left
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -overflow
                }
                // Pause at end
                try? await Task.sleep(for: .seconds(scrollDuration + 1.5))
                // Scroll back
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = 0
                }
                try? await Task.sleep(for: .seconds(scrollDuration))
            }
        }
    }
}

// MARK: - Helper

private extension View {
    func flexibleFrame(width: CGFloat) -> some View {
        frame(width: width)
    }
}
