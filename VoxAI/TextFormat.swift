//
//  TextFormat.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/9/24.
//


import Foundation

enum TextFormat {
    case email
    case message
    case slack
    case terminal
    case `default`
    
    var capitalizesSentences: Bool {
        switch self {
        case .email:
            return true
        default:
            return false
        }
    }
}
