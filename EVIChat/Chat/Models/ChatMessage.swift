//
//  ChatMessage.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ProsodyInference: Codable {
    let scores: [String: Double]
}

struct Inference: Codable {
    let prosody: ProsodyInference?
}
