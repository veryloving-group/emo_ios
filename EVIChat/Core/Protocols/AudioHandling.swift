//
//  AudioHandling.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation
import AVFoundation

protocol AudioServiceDelegate: AnyObject {
    func audioService(_ service: AudioServiceProtocol, didCaptureAudio data: String)
    func audioService(_ service: AudioServiceProtocol, didEncounterError error: Error)
}

protocol AudioServiceProtocol: AnyObject {
    var delegate: AudioServiceDelegate? { get set }
    var isRunning: Bool { get }
    var isMuted: Bool { get set }

    func start() throws
    func stop()
    func playAudio(_ base64Data: String)
    func handleInterruption()
}
