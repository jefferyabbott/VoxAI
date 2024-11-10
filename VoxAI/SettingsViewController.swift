//
//  SettingsViewController.swift
//  VoxAI
//
//  Created by Jeffery Abbott on 11/8/24.
//


import Cocoa
import ServiceManagement


extension Notification.Name {
    static let groqApiKeyChanged = Notification.Name("groqApiKeyChanged")
}

class Settings {

    static let shared = Settings()
    private let keychainKey = "GroqAPIKey"
    
    @UserDefault("casualName", defaultValue: "")
    var casualName: String
    
    @UserDefault("formalName", defaultValue: "")
    var formalName: String
    
    @UserDefault("startAtLogin", defaultValue: false)
    var startAtLogin: Bool
    
    @UserDefault("formalityLevel", defaultValue: 1)
    var formalityLevel: Int
    
    var groqApiKey: String? {
            get {
                return KeychainManager.shared.retrieve(key: keychainKey)
            }
            set {
                if let newValue = newValue {
                    if KeychainManager.shared.save(key: keychainKey, value: newValue) {
                        NotificationCenter.default.post(name: .groqApiKeyChanged, object: nil)
                    } else {
                        print("Failed to save API key to keychain")
                    }
                } else {
                    if KeychainManager.shared.delete(key: keychainKey) {
                        NotificationCenter.default.post(name: .groqApiKeyChanged, object: nil)
                    } else {
                        print("Failed to delete API key from keychain")
                    }
                }
            }
        }
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

class SettingsViewController: NSViewController {
    private let formalityControl: NSSegmentedControl
    private let casualNameField: NSTextField
    private let formalNameField: NSTextField
    private let startAtLoginSwitch: NSSwitch
    private let apiKeyStatusLabel: NSTextField
    private let setApiKeyButton: NSButton
    
    init() {
        self.formalityControl = NSSegmentedControl(labels: ["Casual", "Auto", "Formal"],
                                                 trackingMode: .selectOne,
                                                 target: nil,
                                                 action: nil)
        
        self.casualNameField = NSTextField()
        self.formalNameField = NSTextField()
        self.startAtLoginSwitch = NSSwitch()
        self.apiKeyStatusLabel = NSTextField(labelWithString: "Groq API Key: Not Set")
        self.setApiKeyButton = NSButton(title: "Set API Key", target: nil, action: nil)
        
        super.init(nibName: nil, bundle: nil)
        updateApiKeyStatus()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 620)) // Match window height
        self.view = view
        
        // Main stack view
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 32
        mainStack.alignment = .left
        mainStack.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        // Headers and labels left-aligned
        let nameHeader = createHeader("Your Name")
        let casualNameLabel = createLabel("Casual Name")
        let formalNameLabel = createLabel("Formal Name")
        casualNameField.widthAnchor.constraint(equalToConstant: 210).isActive = true
        formalNameField.widthAnchor.constraint(equalToConstant: 210).isActive = true
        
        let nameGroup = NSStackView()
        nameGroup.orientation = .vertical
        nameGroup.spacing = 16
        nameGroup.alignment = .left
        [casualNameLabel, casualNameField, formalNameLabel, formalNameField].forEach {
            nameGroup.addArrangedSubview($0)
        }
        
        let separator1 = createSeparator()
        
        let groqHeader = createHeader("Groq Service")
        let formalityLabel = createLabel("Message Formality")
        formalityControl.widthAnchor.constraint(equalToConstant: 210).isActive = true
        let apiKeyLabel = createLabel("API Key")

        // Configure the button
        setApiKeyButton.target = self
        setApiKeyButton.action = #selector(setApiKeyTapped)

        let groqGroup = NSStackView()
        groqGroup.orientation = .vertical
        groqGroup.spacing = 16
        groqGroup.alignment = .left
        [formalityLabel, formalityControl, apiKeyLabel, setApiKeyButton].forEach {
            groqGroup.addArrangedSubview($0)
        }
        
        let separator2 = createSeparator()
        
        let loginLabel = createLabel("Start at Login")
        
        // Add to main stack
        [nameHeader, nameGroup, separator1,
         groqHeader, groqGroup, separator2,
         loginLabel, startAtLoginSwitch].forEach { mainStack.addArrangedSubview($0) }
        
        // Position main stack in window
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func createSettingRow(labelText: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.alignment = .left
        
        let label = NSTextField(labelWithString: labelText)
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        
        label.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        if let field = control as? NSTextField {
            field.widthAnchor.constraint(equalToConstant: 110).isActive = true
        } else if control == formalityControl {
            control.widthAnchor.constraint(equalToConstant: 110).isActive = true
        }
        
        row.spacing = 8
        return row
    }

    private func createGroup(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = .left
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func createHeader(_ text: String) -> NSTextField {
        let header = NSTextField(labelWithString: text)
        header.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        header.textColor = .secondaryLabelColor
        header.alignment = .left
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }

    private func createApiKeyStack() -> NSStackView {
        let stack = NSStackView(views: [apiKeyStatusLabel, setApiKeyButton])
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }
    
    private func updateApiKeyStatus() {
            if Settings.shared.groqApiKey != nil {
                apiKeyStatusLabel.stringValue = "Groq API Key: Set"
                setApiKeyButton.title = "Change API Key"
            } else {
                apiKeyStatusLabel.stringValue = "Groq API Key: Not Set"
                setApiKeyButton.title = "Set API Key"
            }
        }
        
    @objc private func setApiKeyTapped() {
        let alert = NSAlert()
        alert.messageText = "Enter Groq API Key"
        alert.alertStyle = .informational
        
        let input = PasteableTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = Settings.shared.groqApiKey ?? ""
        input.placeholderString = "Paste your API key here"
        input.isEditable = true
        input.isSelectable = true
        
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if Settings.shared.groqApiKey != nil {
            alert.addButton(withTitle: "Remove Key")
        }
        
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(input)
        }
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                Settings.shared.groqApiKey = key
            }
        } else if response == .alertThirdButtonReturn {
            Settings.shared.groqApiKey = nil
        }
        
        updateApiKeyStatus()
    }

    
    
    @objc private func formalityChanged(_ sender: NSSegmentedControl) {
        Settings.shared.formalityLevel = sender.selectedSegment
    }
    
    @objc private func casualNameChanged(_ sender: NSTextField) {
        Settings.shared.casualName = sender.stringValue
    }
    
    @objc private func formalNameChanged(_ sender: NSTextField) {
        Settings.shared.formalName = sender.stringValue
    }
    
    @objc private func startAtLoginChanged(_ sender: NSSwitch) {
        Settings.shared.startAtLogin = (sender.state == .on)
        
        if #available(macOS 13.0, *) {
            do {
                if sender.state == .on {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Failed to set login item: \(error.localizedDescription)")
                sender.state = sender.state == .on ? .off : .on
                Settings.shared.startAtLogin = (sender.state == .on)
            }
        } else {
            // For older macOS versions, use the bundle identifier directly
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                if !SMLoginItemSetEnabled(bundleIdentifier as CFString, sender.state == .on) {
                    NSLog("Failed to set login item")
                    // Revert the switch state
                    sender.state = sender.state == .on ? .off : .on
                    Settings.shared.startAtLogin = (sender.state == .on)
                }
            }
        }
    }
}


class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxAI Settings"
        window.contentViewController = SettingsViewController()
        window.center()
        
        self.init(window: window)
    }
}


