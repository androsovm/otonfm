//
//  ArtworkView.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import SwiftUI

struct ArtworkView: View {
    let image: UIImage
    let artworkId: UUID
    let isPlaying: Bool
    @Binding var pulsateAnimation: Bool
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: UIScreen.main.bounds.width * 0.85, height: UIScreen.main.bounds.width * 0.85)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color(image.averageColor ?? .black).opacity(0.6), radius: 25, x: 0, y: 10)
            .scaleEffect(isPlaying && pulsateAnimation ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsateAnimation)
            .animation(.easeInOut(duration: 0.6), value: artworkId)
    }
}