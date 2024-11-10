//
//  PasteableTextField.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/10/24.
//


import Cocoa

class PasteableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "v":
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
