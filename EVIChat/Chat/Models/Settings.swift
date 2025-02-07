//
//  Settings.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

// MARK: - Models/Settings.swift

struct Settings: Codable {
    static let storageKey = "chat_settings"
    
    var voiceActivityDetectionEnabled = true
    var audioQuality = AudioQuality.high
    var showTimestamps = true
    var showEmotionScores = true
    var messageFontSize = FontSize.medium
}

enum AudioQuality: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .low: return "Low (16kHz)"
        case .medium: return "Medium (32kHz)"
        case .high: return "High (48kHz)"
        }
    }
}

enum FontSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var size: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }
}
