//
//  ConnectionButton.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

// MARK: - Views/ConnectionButton.swift

struct ConnectionButton: View {
    let isConnected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(
                isConnected ? "Disconnect" : "Connect",
                systemImage: isConnected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right"
            )
            .symbolRenderingMode(.hierarchical)
            .foregroundColor(isConnected ? .green : .primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}


#Preview {
    ConnectionButton(isConnected: true, action: {})
}
