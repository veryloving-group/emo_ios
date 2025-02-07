//
//  ChatViewModel.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
final class EVIChatViewModel: ObservableObject {
    
    @Published private(set) var isConnected = false
    @Published var isMuted = false
    @Published private(set) var messages: [ChatEntry] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var settings = Settings()
    
    private let audioService: AudioServiceProtocol
    private let webSocketService: WebSocketServiceProtocol
    private let chatService: ChatServiceProtocol
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let userDefaults = UserDefaults.standard
    private let webSocketLock = DispatchQueue(label: "com.evisdk.webSocket")
    private var webSocketTask: URLSessionWebSocketTask?
    
    init(audioService: AudioServiceProtocol,
         webSocketService: WebSocketServiceProtocol,
         chatService: ChatServiceProtocol) {
        self.audioService = audioService
        self.webSocketService = webSocketService
        self.chatService = chatService
        
        setupDelegates()
        loadSettings()
    }
    
    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
        audioService.isMuted = isMuted
    }
    
    func clearChatHistory() {
        chatService.clear()
    }
    
    func refresh() async {
        // Implement refresh logic if needed
    }
    
    func handleAppBecameActive() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        if isConnected {
            reconnect()
        }
    }
    
    func handleAppBecameInactive() {
        // Prepare for background if needed
    }
    
    func handleAppEnteredBackground() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func setupDelegates() {
        audioService.delegate = self
        webSocketService.delegate = self
        chatService.delegate = self
    }
    
    private func connect() {
        do {
            try audioService.start()
            print("🔌 Connecting to WebSocket...")
            webSocketService.connect()
        } catch {
            handleError(error)
        }
    }
    
    private func disconnect() {
        /*audioService.stop*/()
        webSocketService.disconnect()
    }
    
    private func reconnect() {
        disconnect()
        connect()
    }
    
    private func handleError(_ error: Error) {
        Logger.error("Error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
        
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func loadSettings() {
        if let savedSettings = userDefaults.object(Settings.self, forKey: Settings.storageKey) {
            settings = savedSettings
        }
    }
    
    private func saveSettings() {
        userDefaults.save(settings, forKey: Settings.storageKey)
    }
    
    private func sendWebSocketMessage(type: String, data: String) {
        webSocketLock.async { [weak self] in
            let message = ["type": type, "data": data]
            
            print("Message")
            //            print(message)
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }
            
            self?.webSocketService.send(jsonString)
            
        }
    }
    
}
    

extension EVIChatViewModel: @preconcurrency WebSocketServiceDelegate {
    func webSocketService(_ service: WebSocketServiceProtocol, didReceiveMessage message: EVIMessage) {
        Task {
            switch message {
            case .audioOutput(let base64Data):
                if Data(base64Encoded: base64Data) != nil {
                    try audioService.playAudio(base64Data)
                }
            case .error(let errorMessage):
                handleError(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            default:
                chatService.processMessage(message)
            }
        }
    }
    
    func webSocketService(_ service: WebSocketServiceProtocol, didChangeState connected: Bool) {
            Task { @MainActor in
                self.isConnected = connected
                
                if connected {
                    print("✅ WebSocket connected")
                } else {
                    print("❌ WebSocket disconnected")
                }
            }
        }
    
    func webSocketService(_ service: WebSocketServiceProtocol, didEncounterError error: Error) {
        handleError(error)
    }
}

extension EVIChatViewModel: @preconcurrency ChatServiceDelegate {
    func chatService(_ service: ChatServiceProtocol, didUpdateMessages messages: [ChatEntry]) {
        self.messages = messages
    }
    
    func chatService(_ service: ChatServiceProtocol, didEncounterError error: Error) {
        handleError(error)
    }
}

extension EVIChatViewModel: @preconcurrency AudioServiceDelegate {
    func audioService(_ service: AudioServiceProtocol, didCaptureAudio data: String) {
        sendWebSocketMessage(type: "audio_input", data: data)
    }
    
    func audioService(_ service: AudioServiceProtocol, didEncounterError error: Error) {
        handleError(error)
    }
}
