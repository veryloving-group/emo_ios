//
//  EVIChatView.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

struct EVIChatView: View {
    @StateObject private var viewModel: EVIChatViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    
    init(apiKey: String, configId: String) {
        let audioService = AudioService()
        let webSocketService = WebSocketService(apiKey: apiKey, configId: configId)
        let chatService = ChatService()
        
        _viewModel = StateObject(
            wrappedValue: EVIChatViewModel(
                audioService: audioService,
                webSocketService: webSocketService,
                chatService: chatService
            )
        )
    }
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        settingsButton
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            messageList
            
            Divider()
            
            controlBar
                .background(controlBarBackground)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(entry: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages) { _ in
                scrollToLatestMessage(proxy)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var controlBar: some View {
        HStack(spacing: 16) {
            ConnectionButton(
                isConnected: viewModel.isConnected,
                action: {
                    haptics.impactOccurred()
                    viewModel.toggleConnection()
                }
            )
            .accessibilityLabel(viewModel.isConnected ? "Disconnect" : "Connect")
            .accessibilityHint(viewModel.isConnected ? "Tap to disconnect from chat" : "Tap to connect to chat")
            
            MuteButton(
                isMuted: viewModel.isMuted,
                action: {
                    haptics.impactOccurred()
                    viewModel.toggleMute()
                }
            )
            .accessibilityLabel(viewModel.isMuted ? "Unmute" : "Mute")
            .accessibilityHint(viewModel.isMuted ? "Tap to unmute microphone" : "Tap to mute microphone")
        }
        .padding()
    }
    
    private var controlBarBackground: some View {
        Color(.systemBackground)
            .edgesIgnoringSafeArea(.bottom)
            .shadow(color: .black.opacity(0.05), radius: 3, y: -1)
    }
    
    private var settingsButton: some View {
        Button {
            viewModel.showSettings = true
        } label: {
            Image(systemName: "gear")
                .imageScale(.large)
        }
        .accessibilityLabel("Settings")
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    private func scrollToLatestMessage(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            viewModel.handleAppBecameActive()
        case .inactive:
            viewModel.handleAppBecameInactive()
        case .background:
            viewModel.handleAppEnteredBackground()
        @unknown default:
            break
        }
    }
}


//#Preview {
//    EVIChatView(apiKey: "", configId: "")
//}
