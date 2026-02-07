import SwiftUI

/// Large centered album artwork with parallax, floating animation, multi-layer shadow,
/// ambient glow, and cross-fade on change.
struct ArtworkView: View {
    let image: UIImage
    let artworkId: UUID
    let isPlaying: Bool
    let isDefaultArtwork: Bool
    let shadowColor: Color
    var motionManager: MotionManager?

    @State private var isFloating = false

    private var artworkSize: CGFloat {
        UIScreen.main.bounds.width * Constants.Layout.artworkSizeRatio
    }

    var body: some View {
        ZStack {
            // Ambient glow: soft colored light beneath the artwork
            RoundedRectangle(cornerRadius: Constants.Layout.artworkCornerRadius, style: .continuous)
                .fill(shadowColor)
                .frame(width: artworkSize * 0.85, height: artworkSize * 0.85)
                .blur(radius: 60)
                .opacity(isDefaultArtwork ? 0 : 0.5)
                .offset(y: 15)

            // Artwork image with multi-layer shadow
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.artworkCornerRadius, style: .continuous))
                // Near shadow: tight, adds definition
                .shadow(
                    color: isDefaultArtwork ? .clear : shadowColor.opacity(0.5),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                // Far shadow: soft, adds elevation
                .shadow(
                    color: isDefaultArtwork ? .clear : shadowColor.opacity(0.25),
                    radius: 30,
                    x: 0,
                    y: 15
                )
                .rotation3DEffect(
                    .degrees(motionManager?.pitch ?? 0),
                    axis: (x: -1, y: 0, z: 0),
                    perspective: 0.5
                )
                .rotation3DEffect(
                    .degrees(motionManager?.roll ?? 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
        }
        // Floating animation: slow vertical oscillation
        .offset(y: isFloating ? -3 : 3)
        .animation(
            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
            value: isFloating
        )
        .animation(
            .easeInOut(duration: Constants.Animation.artworkTransition),
            value: artworkId
        )
        .onAppear {
            isFloating = true
        }
    }
}
