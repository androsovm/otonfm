//
//  PlayerState.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import Foundation

enum PlayerState: Equatable {
    case stopped
    case connecting
    case playing
    case paused
    case buffering
    case error(RadioError)
    
    var isPlaying: Bool {
        switch self {
        case .playing:
            return true
        default:
            return false
        }
    }
    
    var isConnecting: Bool {
        switch self {
        case .connecting:
            return true
        default:
            return false
        }
    }
    
    var isBuffering: Bool {
        switch self {
        case .buffering:
            return true
        default:
            return false
        }
    }
}