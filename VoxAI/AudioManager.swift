//
//  AudioManager.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//

import Cocoa
import AVFoundation
import Speech

class AudioManager {
    private var isProcessingTranscription = false
    weak var delegate: AudioManagerDelegate?
    private var aiService: AIService?
    
    private var audioEngine: AVAudioEngine
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var monitor: Any?
    var lastTranscription = ""
    
    // Track both fn and shift key states
    private var isFnKeyPressed = false
    private var isShiftKeyPressed = false
    private var wasShiftPressedOnStart = false
    private var hasPendingPaste = false
    
    private var isRecording = false {
        didSet {
            if isRecording {
                delegate?.audioManagerDidStartRecording()
            } else {
                delegate?.audioManagerDidStopRecording()
            }
        }
    }
    
    init(aiService: AIService? = nil) {
        self.aiService = aiService
        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        setupKeyboardMonitoring()
        checkSpeechRecognizerAvailability()
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func checkSpeechRecognizerAvailability() {
        guard let recognizer = speechRecognizer else { return }
        if !recognizer.isAvailable { return }
    }
    
    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleKeyFlags(event)
            return event
        }
        
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleKeyFlags(event)
        }
    }

    private func handleKeyFlags(_ event: NSEvent) {
        _ = NSEvent.ModifierFlags.function
        _ = NSEvent.ModifierFlags.shift
        
        DispatchQueue.main.async {
            // Check if fn key is currently pressed
            let isFnPressed = event.modifierFlags.contains(.function)
            let isShiftPressed = event.modifierFlags.contains(.shift)
            
            // Only update state if fn key state has changed
            if isFnPressed != self.isFnKeyPressed {
                self.isFnKeyPressed = isFnPressed
                
                if isFnPressed {
                    if !self.isRecording && !self.hasPendingPaste {
                        self.wasShiftPressedOnStart = isShiftPressed
                        self.startRecording()
                    }
                } else {
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
            }
            
            self.isShiftKeyPressed = isShiftPressed
        }
    }

    
    private func startRecording() {
            guard !isRecording else { return }
            
            // Clear last transcription and reset processing
            lastTranscription = ""
            isProcessingTranscription = false
            hasPendingPaste = false
            
            // Check if speech recognizer is available
            guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
                delegate?.audioManager(didReceiveError: AudioManagerError.speechRecognizerUnavailable)
                return
            }
            
            // Check microphone authorization
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                break
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            self?.startRecording()
                        }
                    } else {
                        self?.delegate?.audioManager(didReceiveError: AudioManagerError.microphoneAccessDenied)
                    }
                }
                return
            default:
                delegate?.audioManager(didReceiveError: AudioManagerError.microphoneAccessDenied)
                return
            }
            
            // Check speech recognition authorization
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        do {
                            try self?.setupRecognition()
                            self?.isRecording = true
                        } catch {
                            self?.delegate?.audioManager(didReceiveError: error)
                        }
                    default:
                        self?.delegate?.audioManager(didReceiveError: AudioManagerError.speechRecognitionDenied)
                    }
                }
            }
        }
    
    private func setupRecognition() throws {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine = AVAudioEngine()
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw AudioManagerError.recordingFailed
            }
            
            recognitionRequest.shouldReportPartialResults = true
            if #available(macOS 13.0, *) {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            var hasProcessedFinalResult = false
            lastTranscription = ""
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    if !hasProcessedFinalResult &&
                        (error as NSError).domain == "kAFAssistantErrorDomain" &&
                        (error as NSError).code == 1110 &&
                        !self.lastTranscription.isEmpty {
                        hasProcessedFinalResult = true
                        self.processTranscription(self.lastTranscription)
                    }
                    return
                }
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    if !transcription.isEmpty {
                        self.lastTranscription = transcription
                        
                        if result.isFinal && !hasProcessedFinalResult {
                            hasProcessedFinalResult = true
                            self.processTranscription(transcription)
                        }
                    }
                }
            }
        }
    
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
    }
    
    private func processTranscription(_ text: String) {
            Task {
                let formattedText: String
                
                if wasShiftPressedOnStart {
                    if let aiService = aiService {
                        do {
                            let context = createFormattingContext()
                            formattedText = try await aiService.formatText(text, context: context)
                        } catch {
                            formattedText = formatTextForCurrentApp(text)
                        }
                    } else {
                        // Show alert for missing API key
                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "Groq API Key Required"
                            alert.informativeText = "Please set your Groq API key in Settings to use AI formatting."
                            alert.alertStyle = .warning
                            alert.runModal()
                        }
                        formattedText = formatTextForCurrentApp(text)
                    }
                } else {
                    formattedText = formatTextForCurrentApp(text)
                }
                
                await MainActor.run {
                    self.copyToClipboard(formattedText)
                    self.hasPendingPaste = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.pasteToCurrentApp()
                        self.hasPendingPaste = false
                    }
                }
            }
        }
    
    private func createFormattingContext() -> FormattingContext {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName?.lowercased() ?? ""
        
        let appType: TextFormat = {
            switch appName {
            case "mail": return .email
            case "messages": return .message
            case "terminal", "iterm2": return .terminal
            default: return .default
            }
        }()
        
        let formalityIndex = UserDefaults.standard.integer(forKey: "formalityLevel")
        let formality: FormalityLevel = {
            switch formalityIndex {
            case 0: return .casual
            case 2: return .formal
            default: return .auto
            }
        }()
        
        let userPreferences: [String: Any] = [
            "emailSignature": UserDefaults.standard.string(forKey: "emailSignature") ?? "",
            "formalStyle": UserDefaults.standard.bool(forKey: "formalStyle")
        ]
        
        return FormattingContext(
            appName: appName,
            appType: appType,
            formalityLevel: formality,
            userPreferences: userPreferences
        )
    }
    
    private func formatTextForCurrentApp(_ text: String) -> String {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName?.lowercased() ?? ""
        
        switch appName {
        case "mail":
            return formatAsEmail(text)
        case "messages":
            return formatAsMessage(text)
        default:
            return text
        }
    }
    
    private func formatAsEmail(_ text: String) -> String {
        return text
    }
    
    private func formatAsMessage(_ text: String) -> String {
        return text
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func pasteToCurrentApp() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let pasteCommandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let pasteCommandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        pasteCommandDown?.flags = .maskCommand
        pasteCommandUp?.flags = .maskCommand
        
        pasteCommandDown?.post(tap: .cghidEventTap)
        pasteCommandUp?.post(tap: .cghidEventTap)
    }
}

enum AudioManagerError: LocalizedError {
    case speechRecognizerUnavailable
    case microphoneAccessDenied
    case speechRecognitionDenied
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            return "Speech recognizer is not available"
        case .microphoneAccessDenied:
            return "Microphone access is required. Please enable it in System Settings."
        case .speechRecognitionDenied:
            return "Speech recognition access is required. Please enable it in System Settings."
        case .recordingFailed:
            return "Failed to start recording"
        }
    }
}
