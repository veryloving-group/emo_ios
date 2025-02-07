//
//  ChatEntry.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

enum Role: String, Codable {
    case user
    case assistant
}

// MARK: - Models/EmotionScore.swift
struct EmotionScore: Codable, Equatable {
    let emotion: String
    let score: Double
}

// MARK: - Models/ChatEntry.swift
struct ChatEntry: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let timestamp: Date
    let content: String
    let scores: [EmotionScore]
    
    init(id: UUID = UUID(), role: Role, timestamp: Date = Date(), content: String, scores: [EmotionScore]) {
        self.id = id
        self.role = role
        self.timestamp = timestamp
        self.content = content
        self.scores = scores
    }
}
