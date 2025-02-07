//
//  ChatService.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

enum ChatServiceError: LocalizedError {
    case messageProcessingFailed
    case invalidMessageFormat
    
    var errorDescription: String? {
        switch self {
        case .messageProcessingFailed:
            return "Failed to process chat message"
        case .invalidMessageFormat:
            return "Invalid message format"
        }
    }
}

final class ChatService: ChatServiceProtocol {
    
    weak var delegate: ChatServiceDelegate?
    private(set) var messages: [ChatEntry] = []

    func processMessage(_ message: EVIMessage) {
        switch message {
        case .assistantMessage(let chatMessage, let models),
             .userMessage(let chatMessage, let models):
            let entry = createChatEntry(from: chatMessage, models: models)
            messages.append(entry)
            delegate?.chatService(self, didUpdateMessages: messages)
            
        case .error(let errorMessage):
            delegate?.chatService(self, didEncounterError: ChatServiceError.messageProcessingFailed)
            Logger.error("Chat service error: \(errorMessage)")
            
        default:
            break
        }
    }
    
    func clear() {
        messages.removeAll()
        delegate?.chatService(self, didUpdateMessages: messages)
    }
    
    private func createChatEntry(from message: ChatMessage, models: Inference) -> ChatEntry {
        ChatEntry(
            role: message.role == "assistant" ? .assistant : .user,
            timestamp: Date(),
            content: message.content,
            scores: extractEmotionScores(from: models)
        )
    }
    
    private func extractEmotionScores(from models: Inference) -> [EmotionScore] {
        guard let scores = models.prosody?.scores else { return [] }
        return scores.map { EmotionScore(emotion: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { $0 }
    }
}
