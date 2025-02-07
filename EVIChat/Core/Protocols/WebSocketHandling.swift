//
//  WebSocketHandling.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

protocol WebSocketServiceDelegate: AnyObject {
    func webSocketService(_ service: WebSocketServiceProtocol, didReceiveMessage message: EVIMessage)
    func webSocketService(_ service: WebSocketServiceProtocol, didChangeState connected: Bool)
    func webSocketService(_ service: WebSocketServiceProtocol, didEncounterError error: Error)
}

protocol WebSocketServiceProtocol: AnyObject {
    var delegate: WebSocketServiceDelegate? { get set }
    var isConnected: Bool { get }
    
    func connect()
    func disconnect()
    func send(_ message: String)
}
