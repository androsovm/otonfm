//
//  TrackInfo.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import Foundation

struct TrackInfo: Codable, Equatable {
    let title: String
    let artworkUrl: String?
    let artworkUrlLarge: String?
    
    // Computed property for getting the best available artwork URL
    var bestArtworkUrl: String? {
        return artworkUrlLarge ?? artworkUrl
    }
    
    // For JSON parsing from API
    enum CodingKeys: String, CodingKey {
        case title
        case artworkUrl = "artwork_url"
        case artworkUrlLarge = "artwork_url_large"
    }
}

// API Response structure
struct RadioStatusResponse: Codable {
    let currentTrack: TrackInfo?
    let history: [TrackInfo]?
    
    enum CodingKeys: String, CodingKey {
        case currentTrack = "current_track"
        case history
    }
}