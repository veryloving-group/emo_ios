//
//  WebSocketService.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation

enum WebSocketError: LocalizedError {
    case invalidURL
    case connectionFailed
    case messageSendFailed
    case messageReceiveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid WebSocket URL"
        case .connectionFailed: return "Failed to connect to server"
        case .messageSendFailed: return "Failed to send message"
        case .messageReceiveFailed: return "Failed to receive message"
        }
    }
}

final class WebSocketService: NSObject, WebSocketServiceProtocol {
    
    weak var delegate: WebSocketServiceDelegate?
    private(set) var isConnected = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let apiKey: String
    private let configId: String
    
    private var isConnecting = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
    
    init(apiKey: String, configId: String) {
        self.apiKey = apiKey
        self.configId = configId
        super.init()
    }
    
    func connect() {
        
        let baseURL = "wss://api.hume.ai/v0/evi/chat"
        let urlString = configId.isEmpty
            ? "\(baseURL)?api_key=\(apiKey)"
            : "\(baseURL)?api_key=\(apiKey)&config_id=\(configId)"

        guard let url = URL(string: urlString) else {
            delegate?.webSocketService(self, didEncounterError: WebSocketError.invalidURL)
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        sendSessionSettings()
        self.isConnected = true
        delegate?.webSocketService(self, didChangeState: true)
    }
    
        
    private func handleConnectionFailure() {
        isConnecting = false
        isConnected = false
        delegate?.webSocketService(self, didChangeState: false)
        
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            print("🔄 Reconnection attempt \(reconnectAttempts) of \(maxReconnectAttempts)")
            
            let delay = reconnectDelay * pow(2, Double(reconnectAttempts - 1))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.connect()
            }
        } else {
            print("❌ Max reconnection attempts reached")
            delegate?.webSocketService(self, didEncounterError: WebSocketError.connectionFailed)
        }
    }
    
    func send(_ message: String) {
        webSocketTask?.send(.string(message)) { [weak self] error in
            if let error = error {
                print("🔴 Send failed: \(error)")
                self?.handleConnectionFailure()
            }
        }
    }
    
    private func sendSessionSettings() {
        let settings: [String: Any] = [
            "type": "session_settings",
            "audio": [
                "encoding": "linear16",
                "sample_rate": 48000,
                "channels": 1
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: settings),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        print("📡 Sending session settings...")
        send(jsonString)
        print("✅ Session settings sent")
        DispatchQueue.main.async {
            self.receiveMessage()
            self.schedulePing()
        }
    }
        
    private func schedulePing() {
        guard isConnected else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isConnected else { return }
            
            self.webSocketTask?.sendPing { [weak self] error in
                if let error = error {
                    print("🔴 Ping failed: \(error)")
                    self?.handleConnectionFailure()
                } else {
                    self?.schedulePing()
                }
            }
        }
    }
    
    func disconnect() {
        self.webSocketTask?.cancel()
        self.webSocketTask = nil
        self.isConnected = false
        delegate?.webSocketService(self, didChangeState: false)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    print("Received binary message: \(data)")
                @unknown default:
                    break
                }
                self.receiveMessage()
            case .failure(let error):
                self.delegate?.webSocketService(self, didEncounterError: error)
                self.handleReconnection()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let message = try JSONDecoder().decode(EVIMessage.self, from: data)
            delegate?.webSocketService(self, didReceiveMessage: message)
        } catch {
            delegate?.webSocketService(self, didEncounterError: error)
        }
    }
    
    private func handleReconnection() {
        disconnect()
        connect()
    }
}


