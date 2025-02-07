//
//  ChatBubbleView.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

struct ChatBubbleView: View {
    let entry: ChatEntry
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    
    private var isUser: Bool { entry.role == .user }
    
    var body: some View {
        HStack {
            if !isUser { Spacer(minLength: 32) }
            
            VStack(alignment: isUser ? .leading : .trailing, spacing: 4) {
                messageContent
                emotionScores
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            
            if isUser { Spacer(minLength: 32) }
        }
        .padding(.horizontal)
    }
    
    private var messageContent: some View {
        Text(entry.content)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bubbleColor)
            )
            .foregroundColor(textColor)
    }
    
    private var emotionScores: some View {
        Text(formattedScores)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    private var bubbleColor: Color {
        if isUser {
            return .blue.opacity(colorScheme == .dark ? 0.3 : 0.2)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        .primary
    }
    
    private var formattedScores: String {
        entry.scores
            .prefix(3)
            .map { "\($0.emotion) (\(String(format: "%.1f", $0.score)))" }
            .joined(separator: ", ")
    }
    
    private var accessibilityLabel: String {
        let role = isUser ? "You" : "Assistant"
        let emotions = entry.scores
            .prefix(3)
            .map { "\($0.emotion) at \(Int($0.score * 100))%" }
            .joined(separator: ", ")
        
        return "\(role) said: \(entry.content). Emotions detected: \(emotions)"
    }
}

//#Preview {
//    ChatBubbleView()
//}
