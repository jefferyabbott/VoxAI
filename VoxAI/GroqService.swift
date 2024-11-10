//
//  GroqService.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//

import Foundation

protocol AIService {
    func formatText(_ text: String, context: FormattingContext) async throws -> String
}

class GroqService: AIService {
    private let apiKey: String
    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    private func getFormatInstructions(for context: FormattingContext, text: String) -> (systemPrompt: String, userPrompt: String) {
        let informalName = Settings.shared.casualName.isEmpty ? "Your name" : Settings.shared.casualName
        let formalName = Settings.shared.formalName.isEmpty ? "Your name" : Settings.shared.formalName
        let name = context.formalityLevel == .formal ? formalName : informalName
        
        let systemPrompt = """
    You are an AI assistant that helps format text appropriately for different contexts.
    Current app: \(context.appName)
    Context type: \(context.appType)
    Formality level: \(context.formalityLevel)

    When formatting text:
    1. Maintain the core message and meaning
    2. Adjust the tone and structure based on the context
    3. Keep the response concise but complete
    4. Do not add any explanations or additional notes
    5. Return only the formatted text
    6. Format specifically for the current app context
    """
        
        let userPrompt: String
        switch context.appType {
        case .email:
            userPrompt = """
    Format this text as an email:
    - Add appropriate greeting
    - Fix any grammatical errors
    - Structure the message clearly
    - Add professional closing
    - End with signature: \(name)
    - Use \(context.formalityLevel == .formal ? "formal" : "casual") tone
    - Capitalize sentences
    - Return only the formatted email

    Text: \(text)
    """
            
        case .message:
            userPrompt = """
    Format this text as a text message:
    - Keep it conversational and concise
    - Fix any typos but maintain casual style
    - Use appropriate emoji if it fits the context
    - Don't add a signature
    - Use natural messaging language
    - Return only the formatted message

    Text: \(text)
    """
            
        case .slack:
            userPrompt = """
    Format this text as a Slack message:
    - Use Slack-appropriate formatting and style
    - Include markdown when helpful
    - Use appropriate emoji or reactions
    - Keep it professional but friendly
    - Format code blocks if there's code
    - Return only the formatted Slack message

    Text: \(text)
    """
            
    case .terminal:
            userPrompt = """
        Format this text as a terminal command:
        - Convert natural language into a valid command
        - Include appropriate flags and options
        - If comments are needed, prefix them with #COMMENT# (they will be filtered out)
        - Handle file paths and permissions appropriately
        - The first line MUST be the command only, with no prefixes or annotations
        - Do not include any explanatory text or markdown formatting

        Text: \(text)
        """
            
        case .default:
            userPrompt = """
    Format this text appropriately:
    - Fix any grammatical errors or typos
    - Use \(context.formalityLevel == .formal ? "formal" : "casual") tone
    - Structure the content clearly
    - Return only the formatted text

    Text: \(text)
    """
        }
        
        return (systemPrompt, userPrompt)
    }
    
    func formatText(_ text: String, context: FormattingContext) async throws -> String {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompts = getFormatInstructions(for: context, text: text)
        
        let requestBody = [
            "model": "mixtral-8x7b-32768",
            "messages": [
                ["role": "system", "content": prompts.systemPrompt],
                ["role": "user", "content": prompts.userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 1024,
            "stream": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("Groq API Response Status: \(httpResponse.statusCode)")
                NSLog("Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                NSLog("Groq API Raw Response: \(responseString)")
            }
            
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                NSLog("Groq API Error: \(errorMessage)")
                throw NSError(domain: "GroqAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            let parsedResponse = try JSONDecoder().decode(GroqResponse.self, from: data)
            
            guard let formattedText = parsedResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
            }
            
            var finalFormattedText = formattedText
            let replacementName = context.formalityLevel == .formal ?
                Settings.shared.formalName : Settings.shared.casualName
                
            if formattedText.contains("[Your Name]") {
                finalFormattedText = formattedText.replacingOccurrences(
                    of: "[Your Name]",
                    with: replacementName)
            }
            
            if formattedText.contains("Your name") {
                finalFormattedText = formattedText.replacingOccurrences(
                    of: "Your name",
                    with: replacementName)
            }
            
            // Add terminal-specific processing here
            if context.appType == .terminal {
                // Get the first line only for terminal commands
                let lines = finalFormattedText.components(separatedBy: .newlines)
                if let firstLine = lines.first {
                    // Remove any #COMMENT# and everything after it from the line
                    let components = firstLine.components(separatedBy: "#COMMENT#")
                    let command = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    return command
                }
            }
            
            NSLog("Successfully formatted text: \(finalFormattedText)")
            
            return finalFormattedText
            
        } catch {
            NSLog("Error formatting text: \(error.localizedDescription)")
            if let error = error as NSError? {
                NSLog("Error details - Domain: \(error.domain), Code: \(error.code)")
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                    NSLog("Underlying error: \(underlyingError)")
                }
            }
            throw error
        }
    }
}

// Response types for Groq API
struct GroqResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
}

struct Choice: Codable {
    let index: Int
    let message: Message
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}
