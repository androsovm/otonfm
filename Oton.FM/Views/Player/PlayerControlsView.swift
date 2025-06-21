//
//  PlayerControlsView.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import SwiftUI
import CoreHaptics

struct PlayerControlsView: View {
    @ObservedObject var player: RadioPlayer
    @State private var isPressed = false
    @Binding var pulsateAnimation: Bool
    
    let spotifyBlack = Color(red: 24/255, green: 24/255, blue: 24/255)
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: {
                playComplexHaptic()
                
                if player.isPlaying {
                    player.pause()
                } else {
                    player.playStream()
                }
                pulsateAnimation = player.isPlaying
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                    
                    if player.isBuffering && player.isPlaying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: spotifyBlack))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(spotifyBlack)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeOut(duration: 0.2), value: isPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in 
                        isPressed = true
                        playHapticFeedback(.light)
                    }
                    .onEnded { _ in 
                        isPressed = false
                        playHapticFeedback(.light)
                    }
            )
            
            Spacer()
        }
    }
    
    // Haptic feedback functions
    private func playHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func playComplexHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let lightFeedback = UIImpactFeedbackGenerator(style: .light)
            lightFeedback.prepare()
            lightFeedback.impactOccurred()
        }
    }
}