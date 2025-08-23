//
//  AudioService.swift
//  Swift-EVIChat
//
//  Created by Andreas Naoum on 06/02/2025.
//

import Foundation
import AVFoundation
import AudioToolbox

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
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Simulator detection
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private var audioTimer: Timer?
    
    // Audio playback properties
    private var audioPlaybackQueue: [URL] = []
    private var isAudioPlaying = false
    private var currentAudioPlayer: AVAudioPlayer?
    
    // Audio format configuration
    private var nativeInputFormat: AVAudioFormat?
    
    private let bufferSizeFrames: AVAudioFrameCount = 4800 // 100ms at 48kHz
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine?.inputNode
        
        if isSimulator {
            print("📱 Running on iOS Simulator - will attempt real microphone")
            // Use delayed setup to avoid HAL timing issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupAudioSession()
                self.setupAudioEngine()
            }
        } else {
            setupAudioSession()
            setupAudioEngine()
        }
    }
    
    // MARK: - Public Methods
    func start() throws {
        guard !isRunning else { return }
        
        guard let audioEngine = audioEngine else {
            throw AudioServiceError.engineStartFailed
        }
        
        if isSimulator {
            // Give extra time for simulator audio setup
            print("📱 Starting real microphone on simulator...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.attemptRealAudioStart()
            }
            return
        }
        
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
        
        // Stop both real audio and fallback timer
        audioTimer?.invalidate()
        audioTimer = nil
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
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
        guard let audioEngine = audioEngine, let inputNode = inputNode else {
            print("❌ Audio engine components not available")
            return
        }
        
        print("🎛️ Setting up audio engine...")
        
        let mainMixer = audioEngine.mainMixerNode
        print("Main mixer format: \(mainMixer.outputFormat(forBus: 0))")
        
        if let inputFormat = nativeInputFormat {
            print("Connecting input with format: \(inputFormat)")
            audioEngine.connect(inputNode, to: mainMixer, format: inputFormat)
            print("✅ Input connected to mixer")
        }
        
        audioEngine.prepare()
        print("✅ Audio engine prepared")
    }
    
    private func setupAudioSession() {
        guard let inputNode = inputNode else { return }
        
        do {
            print("🎧 Setting up audio session...")
            
            if isSimulator {
                // More permissive settings for simulator
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetooth])
                try audioSession.setPreferredSampleRate(48000)
                try audioSession.setPreferredInputNumberOfChannels(1)
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            }
            
            try audioSession.setActive(true)
            
            print("✅ Audio Session Setup Successful")
            print("Sample rate: \(audioSession.sampleRate)")
            print("Input channels: \(audioSession.inputNumberOfChannels)")
            
            // Delay format detection to avoid simulator HAL issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.nativeInputFormat = inputNode.inputFormat(forBus: 0)
                print("Native format: \(String(describing: self.nativeInputFormat))")
            }
            
        } catch {
            print("🚨 Audio Session Setup Failed: \(error)")
        }
    }
    
    private func attemptRealAudioStart() {
        guard let audioEngine = audioEngine else {
            print("❌ Audio engine not available, falling back to mock audio")
            startSimulatorAudio()
            isRunning = true
            return
        }
        
        do {
            print("🎧 Attempting to start real audio engine on simulator...")
            try audioEngine.start()
            print("✅ Real audio engine started on simulator!")
            startRecording()
            isRunning = true
        } catch {
            print("⚠️ Real audio failed on simulator: \(error)")
            print("📱 Falling back to mock audio for demo")
            startSimulatorAudio()
            isRunning = true
        }
    }
    
    
    private func startRecording() {
        guard let inputNode = inputNode else {
            print("❌ Input node not available")
            return
        }
        
        print("🎤 Starting audio recording...")
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        // Use the native input format
        guard let inputFormat = nativeInputFormat else {
            print("❌ No input format available")
            delegate?.audioService(self, didEncounterError: AudioServiceError.engineStartFailed)
            return
        }
        
        print("Recording format: \(inputFormat)")
        
        // Install tap with the native format
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isMuted else { return }
            self.processAudioBuffer(buffer)
        }
        
        print("✅ Audio recording started")
    }
    
    private func startSimulatorAudio() {
        print("🎭 Starting simulator mock audio")
        
        // Generate realistic test audio data periodically
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isRunning else {
                timer.invalidate()
                return
            }
            
            if !self.isMuted {
                // Generate some test audio data (gentle sine wave converted to 16-bit)
                let sampleRate: Double = 48000
                let duration: Double = 0.1 // 100ms
                let frameCount = Int(sampleRate * duration)
                
                var audioData = Data()
                let frequency: Double = 440.0 // A4 note
                
                for i in 0..<frameCount {
                    let time = Double(i) / sampleRate
                    let amplitude = sin(2.0 * Double.pi * frequency * time) * 0.1 // Quiet sine wave
                    let sample = Int16(amplitude * 32767.0)
                    
                    withUnsafeBytes(of: sample.littleEndian) { bytes in
                        audioData.append(contentsOf: bytes)
                    }
                }
                
                self.delegate?.audioService(self, didCaptureAudio: audioData.base64EncodedString())
            }
        }
        
        print("✅ Simulator mock audio started")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to 16-bit PCM at 48kHz for EVI
        let audioData = convertAudioToEVIFormat(buffer)
        delegate?.audioService(self, didCaptureAudio: audioData.base64EncodedString())
    }
    
    private func convertAudioToEVIFormat(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let floatData = buffer.floatChannelData?[0] else {
            return Data()
        }
        
        let frameLength = Int(buffer.frameLength)
        let inputSampleRate = buffer.format.sampleRate
        let targetSampleRate: Double = 48000
        
        // Simple sample rate conversion if needed
        var outputFrames: [Int16] = []
        
        if inputSampleRate == targetSampleRate {
            // Direct conversion
            for frame in 0..<frameLength {
                let floatSample = floatData[frame]
                let scaledSample = max(-1.0, min(floatSample, 1.0)) * 32767.0
                outputFrames.append(Int16(scaledSample))
            }
        } else {
            // Simple linear interpolation for sample rate conversion
            let ratio = inputSampleRate / targetSampleRate
            let outputLength = Int(Double(frameLength) / ratio)
            
            for i in 0..<outputLength {
                let inputIndex = Double(i) * ratio
                let lowerIndex = Int(inputIndex)
                let upperIndex = min(lowerIndex + 1, frameLength - 1)
                let fraction = inputIndex - Double(lowerIndex)
                
                let lowerSample = floatData[lowerIndex]
                let upperSample = floatData[upperIndex]
                let interpolatedSample = lowerSample + Float(fraction) * (upperSample - lowerSample)
                
                let scaledSample = max(-1.0, min(interpolatedSample, 1.0)) * 32767.0
                outputFrames.append(Int16(scaledSample))
            }
        }
        
        return Data(bytes: outputFrames, count: outputFrames.count * 2)
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

