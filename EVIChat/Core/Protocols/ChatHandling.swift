//
//  ChatHandling.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

protocol ChatServiceDelegate: AnyObject {
    func chatService(_ service: ChatServiceProtocol, didUpdateMessages messages: [ChatEntry])
    func chatService(_ service: ChatServiceProtocol, didEncounterError error: Error)
}

protocol ChatServiceProtocol: AnyObject {
    var delegate: ChatServiceDelegate? { get set }
    var messages: [ChatEntry] { get }
    
    func processMessage(_ message: EVIMessage)
    func clear()
}
