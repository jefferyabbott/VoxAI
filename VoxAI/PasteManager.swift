//
//  PasteManager.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/12/24.
//

import Cocoa

class PasteManager {
    private var aiService: AIService?
    
    init(aiService: AIService? = nil) {
        self.aiService = aiService
    }
    
    func processAndPasteText(_ text: String, withAI: Bool) {
        Task {
            var formattedText: String
            
            if withAI {
                if let aiService = aiService {
                    do {
                        let context = createFormattingContext()
                        let aiFormattedText = try await aiService.formatText(text, context: context)
                        formattedText = removeSubjectLine(from: aiFormattedText)
                    } catch {
                        formattedText = removeSubjectLine(from: text)
                    }
                } else {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Groq API Key Required"
                        alert.informativeText = "Please set your Groq API key in Settings to use AI formatting."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                    formattedText = removeSubjectLine(from: text)
                }
            } else {
                formattedText = removeSubjectLine(from: text)
            }
            
            await MainActor.run {
                copyToClipboard(formattedText)
                performPaste()
            }
        }
    }
    
    private func removeSubjectLine(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        if let firstLine = lines.first,
           firstLine.lowercased().starts(with: "subject:") {
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func performPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let pasteCommandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let pasteCommandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        pasteCommandDown?.flags = .maskCommand
        pasteCommandUp?.flags = .maskCommand
        
        pasteCommandDown?.post(tap: .cghidEventTap)
        pasteCommandUp?.post(tap: .cghidEventTap)
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
            "formalStyle": UserDefaults.standard.bool(forKey: "formalStyle")
        ]
        
        return FormattingContext(
            appName: appName,
            appType: appType,
            formalityLevel: formality,
            userPreferences: userPreferences
        )
    }
}
