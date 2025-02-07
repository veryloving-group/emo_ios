//
//  ChatLoadingView.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

struct ChatLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Connecting...")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ChatLoadingView()
}
