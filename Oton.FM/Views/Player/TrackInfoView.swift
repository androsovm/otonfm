//
//  TrackInfoView.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import SwiftUI

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
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                } else if isPlaying && !trackTitle.isEmpty {
                    Text(trackTitle)
                        .id(trackTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(height: 60, alignment: .leading)
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("OTON FM")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(height: 60, alignment: .leading)
                        .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isConnecting)
            .animation(.easeInOut(duration: 0.5), value: trackTitle)
            .animation(.easeInOut(duration: 0.5), value: isPlaying)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, UIScreen.main.bounds.width * 0.075)
        .offset(y: -40) // Поднимаем текст на 40pt вверх
    }
}