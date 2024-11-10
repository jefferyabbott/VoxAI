//
//  FormattingContext.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//

import Foundation

enum FormalityLevel {
    case formal
    case casual
    case auto
}

struct FormattingContext {
    let appName: String
    let appType: TextFormat
    let formalityLevel: FormalityLevel
    let userPreferences: [String: Any]
    
    var systemPrompt: String {
        let basePrompt = """
        You are an AI assistant that helps format text appropriately.
        Current context: Writing in \(appName)
        Formality level: \(formalityLevel)
        """
        
        switch (appType, formalityLevel) {
        case (.email, .formal):
            return basePrompt + """
            \n
            Format this text as a formal professional email:
            - Add appropriate formal greetings and closings
            - Maintain professional tone
            - Structure in clear paragraphs
            """
        case (.email, .casual):
            return basePrompt + """
            \n
            Format this text as a casual but professional email:
            - Add friendly greetings and closings
            - Keep tone conversational but respectful
            - Maintain clear structure
            """
        case (.message, _):
            return basePrompt + """
            \n
            Format this as a casual message:
            - Keep it brief and conversational
            - Use natural language
            - Maintain the core message
            """
        case (.terminal, _):
            return basePrompt + """
            \n
            Convert this natural language into appropriate terminal commands:
            - Use proper command syntax
            - Include necessary flags and options
            - Maintain the intended operation
            """
        default:
            return basePrompt + """
            \n
            Format this text appropriately while maintaining its original meaning.
            """
        }
    }
}
