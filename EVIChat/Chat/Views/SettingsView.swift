//
//  SettingsView.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: EVIChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
//                Section("Audio") {
//                    Toggle("Enable Voice Activity Detection", isOn: $viewModel.settings.voiceActivityDetectionEnabled)
//                    
//                    Picker("Audio Quality", selection: $viewModel.settings.audioQuality) {
//                        ForEach(AudioQuality.allCases) { quality in
//                            Text(quality.description)
//                                .tag(quality)
//                        }
//                    }
//                }
                
                Section("Chat") {
                    Toggle("Show Timestamps", isOn: $viewModel.settings.showTimestamps)
                    Toggle("Show Emotion Scores", isOn: $viewModel.settings.showEmotionScores)
                    
                    Picker("Message Font Size", selection: $viewModel.settings.messageFontSize) {
                        ForEach(FontSize.allCases) { size in
                            Text(size.description)
                                .tag(size)
                        }
                    }
                }
                
                Section("Data") {
                    Button(role: .destructive) {
                        viewModel.clearChatHistory()
                    } label: {
                        Text("Clear Chat History")
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                    LabeledContent("Build", value: Bundle.main.buildNumber)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

//#Preview {
//    SettingsView()
//}
