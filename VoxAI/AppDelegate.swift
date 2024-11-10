//
//  AppDelegate.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//

import Cocoa
import AVFoundation
import Speech

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioManager: AudioManager!
    private var settingsWindowController: SettingsWindowController?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Groq service with API key from settings
        initializeGroqService()
        
        setupStatusItem()
        setupPermissions()
        
        // Run without a dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Listen for API key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApiKeyChange),
            name: .groqApiKeyChanged,
            object: nil
        )
    }
    
    private func initializeGroqService() {
        var groqService: GroqService? = nil
        if let apiKey = Settings.shared.groqApiKey {
            print("Found API key: initializing GroqService")
            groqService = GroqService(apiKey: apiKey)
        } else {
            print("No API key found in settings")
        }
        
        audioManager = AudioManager(aiService: groqService)
        audioManager.delegate = self
    }
    
    @objc private func handleApiKeyChange(_ notification: Notification) {
        print("API key changed, reinitializing Groq service")
        initializeGroqService()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "VoxAI")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        
        settingsWindowController?.window?.center()
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                self.showPermissionAlert(for: "Microphone")
            }
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                self.showPermissionAlert(for: "Speech Recognition")
            }
        }
    }
    
    private func showPermissionAlert(for type: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "\(type) Access Required"
            alert.informativeText = "Please enable \(type) access in System Settings to use VoxAI."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            }
        }
    }
}

extension AppDelegate: AudioManagerDelegate {
    func audioManagerDidStartRecording() {
        DispatchQueue.main.async {
            self.statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
        }
    }
    
    func audioManagerDidStopRecording() {
        DispatchQueue.main.async {
            self.statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Dictation")
        }
    }
    
    func audioManager(didReceiveError error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Recording Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
