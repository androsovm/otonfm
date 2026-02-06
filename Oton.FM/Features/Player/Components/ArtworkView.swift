import SwiftUI

/// Large centered album artwork with parallax, pulsation, shadow, and cross-fade on change.
struct ArtworkView: View {
    let image: UIImage
    let artworkId: UUID
    let isPlaying: Bool
    let isDefaultArtwork: Bool
    @Binding var pulsateAnimation: Bool
    let shadowColor: Color
    var motionManager: MotionManager?

    private var artworkSize: CGFloat {
        UIScreen.main.bounds.width * Constants.Layout.artworkSizeRatio
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.artworkCornerRadius, style: .continuous))
            .shadow(
                color: isDefaultArtwork ? .clear : shadowColor.opacity(Constants.Layout.artworkShadowOpacity),
                radius: Constants.Layout.artworkShadowRadius,
                x: 0,
                y: Constants.Layout.artworkShadowOffsetY
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
            .scaleEffect(isPlaying && pulsateAnimation ? Constants.Layout.pulsationScale : 1.0)
            .animation(
                .easeInOut(duration: Constants.Animation.pulsationDuration)
                    .repeatForever(autoreverses: true),
                value: pulsateAnimation
            )
            .animation(
                .easeInOut(duration: Constants.Animation.artworkTransition),
                value: artworkId
            )
    }
}
