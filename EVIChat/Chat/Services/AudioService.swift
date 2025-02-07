//
//  AudioService.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation
import AVFoundation

enum AudioServiceError: LocalizedError {
    case engineStartFailed
    case invalidData
    case bufferCreationFailed
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .engineStartFailed:
            return "Failed to start audio engine"
        case .invalidData:
            return "Invalid audio data received"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .playbackFailed:
            return "Failed to play audio"
        }
    }
}

final class AudioService: NSObject, AudioServiceProtocol, AVAudioPlayerDelegate {
    // MARK: - Properties
    weak var delegate: AudioServiceDelegate?
    private(set) var isRunning = false
    var isMuted = false
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Audio playback properties
    private var audioPlaybackQueue: [URL] = []
    private var isAudioPlaying = false
    private var currentAudioPlayer: AVAudioPlayer?
    
    // Audio format configuration
    private var nativeInputFormat: AVAudioFormat?
    private let eviAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 48000,
        channels: 1,
        interleaved: true
    )!
    
    private let bufferSizeFrames: AVAudioFrameCount = 4800 // 100ms at 48kHz
    
    // MARK: - Initialization
    override init() {
        self.inputNode = audioEngine.inputNode
        self.nativeInputFormat = inputNode.inputFormat(forBus: 0)
        
        super.init()
        
        setupAudioEngine()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    func start() throws {
        guard !isRunning else { return }
        
        do {
            print("🎧 Starting audio engine...")
            try audioEngine.start()
            print("✅ Audio engine started")
            print("🎤 Starting recording...")
            startRecording()
            print("✅ Recording started")
            isRunning = true
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw AudioServiceError.engineStartFailed
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        handleInterruption()
        isRunning = false
    }
    
    func handleInterruption() {
        // Stop current playback
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        
        // Clean up queue
        for fileURL in audioPlaybackQueue {
            cleanupFile(at: fileURL)
        }
        audioPlaybackQueue.removeAll()
        
        // Reset state
        isAudioPlaying = false
    }
    
    func playAudio(_ base64Data: String) {
        // Decode base64 audio data
        guard let audioData = Data(base64Encoded: base64Data) else {
            delegate?.audioService(self, didEncounterError: AudioServiceError.invalidData)
            return
        }
        
        // Create a temporary file URL
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        do {
            // Write audio data to temporary file
            try audioData.write(to: temporaryFileURL)
            
            // Add to audio playback queue
            audioPlaybackQueue.append(temporaryFileURL)
            
            // Start playback if not already playing
            processAudioPlaybackQueue()
        } catch {
            delegate?.audioService(self, didEncounterError: error)
        }
    }
    
    private func setupAudioEngine() {
            print("🎛️ Setting up audio engine...")
            
            let mainMixer = audioEngine.mainMixerNode
            print("   - Main mixer format: \(mainMixer.outputFormat(forBus: 0))")
            
            if let inputFormat = nativeInputFormat {
                print("   - Connecting input with format: \(inputFormat)")
                audioEngine.connect(inputNode, to: mainMixer, format: inputFormat)
                print("✅ Input connected to mixer")
            } else {
                print("❌ No input format available")
            }
            
            audioEngine.prepare()
            print("✅ Audio engine prepared")
        }
    
    private func setupAudioSessionOld() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            delegate?.audioService(self, didEncounterError: error)
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,  // Using voiceChat for echo cancellation
                options: [
                    .mixWithOthers,
//                    .defaultToSpeaker,  // This helps with speech recognition
//                    .allowBluetooth
                ]
            )
            
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredInputNumberOfChannels(1)
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ Audio Session Setup Successful")
            print("Actual sample rate: \(audioSession.sampleRate)")
            print("Actual IO buffer duration: \(audioSession.ioBufferDuration)")
            print("Input number of channels: \(audioSession.inputNumberOfChannels)")
        } catch {
            print("🚨 Audio Session Setup Failed: \(error)")
        }
    }
    
    private func startRecording() {
            print("🎤 Starting audio recording setup...")
            inputNode.removeTap(onBus: 0)
            
            if let inputFormat = nativeInputFormat {
                print("📊 Input format detected:")
                print("   - Sample rate: \(inputFormat.sampleRate)")
                print("   - Channels: \(inputFormat.channelCount)")
                print("   - Format flags: \(inputFormat.commonFormat.rawValue)")
                
                inputNode.installTap(
                    onBus: 0,
                    bufferSize: bufferSizeFrames,
                    format: inputFormat
                ) { [weak self] buffer, _ in
                    print("🎙️ Received audio buffer with \(buffer.frameLength) frames")
                    self?.processAudioBuffer(buffer)
                }
                print("✅ Audio tap installed successfully")
            } else {
                
                print("❌ Failed to get native input format")
            }
        }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard !isMuted else { return }
        
        // Create a new buffer with the target format (Int16)
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: eviAudioFormat,
            frameCapacity: buffer.frameLength
        ) else {
            delegate?.audioService(self, didEncounterError: AudioServiceError.bufferCreationFailed)
            return
        }
        
        let floatData = buffer.floatChannelData?[0]
        let int16Data = convertedBuffer.int16ChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        
        for frame in 0..<frameLength {
            let floatSample = floatData?[frame] ?? 0
            let scaledSample = max(-1.0, min(floatSample, 1.0)) * 32767.0
            int16Data?[frame] = Int16(scaledSample)
        }
        
        convertedBuffer.frameLength = buffer.frameLength
        
        guard let channelData = convertedBuffer.int16ChannelData?[0] else { return }
        
        let byteCount = Int(convertedBuffer.frameLength * 2)
        let audioData = Data(bytes: channelData, count: byteCount)
        
        delegate?.audioService(self, didCaptureAudio: audioData.base64EncodedString())
    }
    
    private func processAudioPlaybackQueue() {
        guard !isAudioPlaying, !audioPlaybackQueue.isEmpty else { return }
        
        let fileToPlay = audioPlaybackQueue.removeFirst()
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: fileToPlay)
            audioPlayer.delegate = self
            
            isAudioPlaying = true
            
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            
            currentAudioPlayer = audioPlayer
        } catch {
            cleanupFile(at: fileToPlay)
            delegate?.audioService(self, didEncounterError: error)
            
            isAudioPlaying = false
            processAudioPlaybackQueue()
        }
    }
    
    private func cleanupFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let currentURL = currentAudioPlayer?.url {
            cleanupFile(at: currentURL)
        }
        
        currentAudioPlayer = nil
        isAudioPlaying = false
        
        DispatchQueue.main.async { [weak self] in
            self?.processAudioPlaybackQueue()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            delegate?.audioService(self, didEncounterError: error)
        }
        
        if let currentURL = currentAudioPlayer?.url {
            cleanupFile(at: currentURL)
        }
        
        currentAudioPlayer = nil
        isAudioPlaying = false
        
        DispatchQueue.main.async { [weak self] in
            self?.processAudioPlaybackQueue()
        }
    }
}

