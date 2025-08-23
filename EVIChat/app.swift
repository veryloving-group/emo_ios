//
//  Swift_EVIChatApp.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import SwiftUI

@main
struct Swift_EVIChatApp: App {
    
    
    var body: some Scene {
        WindowGroup {
            EVIChatView(
                apiKey: "YOUR_API_KEY_HERE",
                configId: ""
            )
        }
    }
}
