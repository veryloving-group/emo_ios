# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a native iOS client for Hume AI's Empathic Voice Interface (EVI) API, built with Swift and SwiftUI. The app provides real-time conversational AI with voice interaction capabilities.

⚠️ **Warning**: This is a prototype in development and NOT production-ready.

## Build and Run

### Requirements
- iOS 17.6+ (deployment target)  
- Xcode 14.0+
- Swift 5.0+

### Building the Project
```bash
# Open the Xcode project
open Swift-EVIChat.xcodeproj

# Build from command line (if needed)
xcodebuild -project Swift-EVIChat.xcodeproj -scheme Swift-EVIChat -destination "platform=iOS Simulator,name=iPhone 15" build
```

### Configuration
- API key is currently hardcoded in `EVIChat/app.swift:17` 
- The app requires microphone permissions for voice interaction
- Background audio processing is enabled via Info.plist settings

## Architecture

### Project Structure
```
EVIChat/
├── Chat/
│   ├── Models/          # Data models (ChatEntry, EVIMessage, Settings)
│   ├── Services/        # Core services (Audio, WebSocket, Chat)
│   ├── ViewModels/      # MVVM view models (ChatViewModel)
│   └── Views/           # SwiftUI views and UI components
├── Core/
│   ├── Extensions/      # Swift extensions (Bundle+Version)
│   └── Protocols/       # Service protocols and interfaces
└── Utils/               # Utilities (Logger)
```

### Key Components

**Services Layer:**
- `WebSocketService`: Manages WebSocket connection to Hume AI API at `wss://api.hume.ai/v0/evi/chat`
- `AudioService`: Handles microphone input and audio playback (Linear16, 48kHz, 1 channel)
- `ChatService`: Processes and manages chat messages and conversation state

**Architecture Pattern:**
- MVVM with SwiftUI
- Protocol-based dependency injection
- Delegate pattern for service communication
- Service protocols define interfaces: `AudioServiceProtocol`, `WebSocketServiceProtocol`, `ChatServiceProtocol`

**Message Flow:**
1. Audio captured via `AudioService` → Base64 encoded
2. Sent through `WebSocketService` as JSON messages
3. EVI responses processed by `ChatService`
4. UI updated via `ChatViewModel` using `@Published` properties

### Key Technical Details

**WebSocket Communication:**
- Session settings sent on connection with audio configuration
- Automatic reconnection with exponential backoff (max 5 attempts)
- Ping/pong keepalive every 30 seconds

**Audio Processing:**
- Real-time audio capture and playback
- Base64 encoding for WebSocket transmission
- Background audio support enabled

**State Management:**
- `@MainActor` isolation for UI updates
- UserDefaults for settings persistence
- Background task handling for iOS lifecycle

## Development Notes

- The main entry point is `app.swift` with the API key configuration
- Settings are stored in UserDefaults with a custom storage extension
- Error handling uses localized error descriptions
- The app supports background processing for continuous audio streaming
- Protocol-based architecture makes components testable and mockable

## API Integration

The app connects to Hume AI's EVI WebSocket API:
- Base URL: `wss://api.hume.ai/v0/evi/chat`
- Authentication via API key query parameter
- Optional config_id parameter for custom configurations
- JSON message format with type-based message handling