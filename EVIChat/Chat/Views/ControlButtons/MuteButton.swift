//
//  MuteButton.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

// MARK: - Views/MuteButton.swift

struct MuteButton: View {
    let isMuted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(
                isMuted ? "Unmute" : "Mute",
                systemImage: isMuted ? "mic.slash" : "mic"
            )
            .symbolRenderingMode(.hierarchical)
            .foregroundColor(isMuted ? .red : .primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

//#Preview {
//    MuteButton()
//}
