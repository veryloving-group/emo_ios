//
//  EVIMessage.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

enum EVIMessage: Decodable {
    case error(message: String)
    case chatMetadata(metadata: [String: String])
    case audioOutput(data: String)
    case userInterruption
    case assistantMessage(message: ChatMessage, models: Inference)
    case userMessage(message: ChatMessage, models: Inference)
    case unknown
    
    private enum CodingKeys: String, CodingKey {
        case type, message, data, models
        case chatGroupId = "chat_group_id"
        case chatId = "chat_id"
        case requestId = "request_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "chat_metadata":
            var metadata: [String: String] = [:]
            let chatGroupId = try container.decodeIfPresent(String.self, forKey: .chatGroupId) ?? ""
            let chatId = try container.decodeIfPresent(String.self, forKey: .chatId) ?? ""
            let requestId = try container.decodeIfPresent(String.self, forKey: .requestId) ?? ""
            metadata["chat_group_id"] = chatGroupId
            metadata["chat_id"] = chatId
            metadata["request_id"] = requestId
            self = .chatMetadata(metadata: metadata)
        case "audio_output":
            let data = try container.decode(String.self, forKey: .data)
            self = .audioOutput(data: data)
        case "user_interruption":
            self = .userInterruption
        case "assistant_message", "user_message":
            let message = try container.decode(ChatMessage.self, forKey: .message)
            let models = try container.decode(Inference.self, forKey: .models)
            self = type == "assistant_message" ?
                .assistantMessage(message: message, models: models) :
                .userMessage(message: message, models: models)
        default:
            self = .unknown
        }
    }
}
