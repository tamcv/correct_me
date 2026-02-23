import Cocoa
import Foundation

/// NSWindow-based onboarding wizard shown on first launch (no config file present).
/// Steps: Welcome → Choose Provider → Enter API Key → Accessibility → Hotkey → Done
class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var contentView: NSView!

    /// Callback fired after the wizard finishes (saved config + user clicked "Start").
    var onComplete: (() -> Void)?

    // State
    private var selectedProvider: Config.AIProvider = .claudeCode
    private var apiKey: String = ""
    private var selectedHotkey: Config.HotkeyConfig = .default
    private var selectedModel: String?

    private var currentStep = 0
    private let totalSteps = 5 // 0..4

    // MARK: - Show

    func show(completion: @escaping () -> Void) {
        onComplete = completion

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to CorrectMe"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.level = .floating

        contentView = NSView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        w.contentView = contentView

        window = w

        currentStep = 0
        renderStep()

        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Step Rendering

    private func renderStep() {
        contentView.subviews.forEach { $0.removeFromSuperview() }

        switch currentStep {
        case 0: renderWelcome()
        case 1: renderProviderStep()
        case 2: renderAPIKeyStep()
        case 3: renderAccessibilityStep()
        case 4: renderHotkeyStep()
        default: renderDoneStep()
        }

        renderStepIndicator()
    }

    // MARK: - Step 0: Welcome

    private func renderWelcome() {
        let bounds = contentView.bounds

        let icon = NSTextField(labelWithString: "✏️")
        icon.font = .systemFont(ofSize: 64)
        icon.alignment = .center
        icon.frame = NSRect(x: 0, y: bounds.height - 120, width: bounds.width, height: 80)
        icon.autoresizingMask = [.width]
        contentView.addSubview(icon)

        let title = NSTextField(labelWithString: "Welcome to CorrectMe")
        title.font = .boldSystemFont(ofSize: 22)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 170, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "CorrectMe corrects your text with AI. Select any text, press a hotkey, and get instant corrections.\n\nLet's set it up in a few steps.")
        desc.font = .systemFont(ofSize: 14)
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: bounds.height - 270, width: bounds.width - 80, height: 80)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        addNavigationButtons(showBack: false)
    }

    // MARK: - Step 1: Choose Provider

    private var providerPopup: NSPopUpButton?

    private func renderProviderStep() {
        let bounds = contentView.bounds

        let title = NSTextField(labelWithString: "Choose your AI Provider")
        title.font = .boldSystemFont(ofSize: 18)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "Select the AI provider you want to use for text corrections. CLI-based providers (Claude Code, Codex Code, Copilot) require no API key. API providers need a key.")
        desc.font = .systemFont(ofSize: 13)
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: bounds.height - 150, width: bounds.width - 80, height: 50)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        let popup = NSPopUpButton(frame: NSRect(x: 60, y: bounds.height - 200, width: bounds.width - 120, height: 30))
        popup.autoresizingMask = [.width]

        let providers: [(Config.AIProvider, String)] = [
            (.claudeCode, "Claude Code (local CLI)"),
            (.codexCode, "Codex Code (local CLI)"),
            (.copilot, "GitHub Copilot (local CLI)"),
            (.claude, "Claude API (key required)"),
            (.gemini, "Gemini API (key required)"),
            (.codex, "OpenAI / Codex API (key required)"),
        ]

        for (_, label) in providers {
            popup.addItem(withTitle: label)
        }

        // Select current
        if let idx = providers.firstIndex(where: { $0.0 == selectedProvider }) {
            popup.selectItem(at: idx)
        }

        popup.target = self
        popup.action = #selector(providerChanged(_:))
        providerPopup = popup
        contentView.addSubview(popup)

        // Status label for CLI availability
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.tag = 100
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 40, y: bounds.height - 240, width: bounds.width - 80, height: 20)
        statusLabel.autoresizingMask = [.width]
        contentView.addSubview(statusLabel)
        updateProviderStatus()

        addNavigationButtons(showBack: true)
    }

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        let providers: [Config.AIProvider] = [.claudeCode, .codexCode, .copilot, .claude, .gemini, .codex]
        selectedProvider = providers[sender.indexOfSelectedItem]
        updateProviderStatus()
    }

    private func updateProviderStatus() {
        guard let label = contentView.viewWithTag(100) as? NSTextField else { return }

        switch selectedProvider {
        case .claudeCode:
            let found = findExecutable("claude") != nil
            label.stringValue = found ? "claude CLI found" : "claude CLI not found — install Claude Code first"
            label.textColor = found ? .systemGreen : .systemOrange
        case .codexCode:
            let found = findExecutable("codex") != nil
            label.stringValue = found ? "codex CLI found" : "codex CLI not found — install Codex first"
            label.textColor = found ? .systemGreen : .systemOrange
        case .copilot:
            let found = findExecutable("gh") != nil
            label.stringValue = found ? "gh CLI found" : "gh CLI not found — install with: brew install gh"
            label.textColor = found ? .systemGreen : .systemOrange
        case .claude:
            label.stringValue = "Requires an Anthropic API key"
            label.textColor = .secondaryLabelColor
        case .gemini:
            label.stringValue = "Requires a Google Gemini API key"
            label.textColor = .secondaryLabelColor
        case .codex:
            label.stringValue = "Requires an OpenAI API key"
            label.textColor = .secondaryLabelColor
        }
    }

    // MARK: - Step 2: API Key

    private var apiKeyField: NSSecureTextField?
    private var testResultLabel: NSTextField?
    private var testButton: NSButton?

    private func renderAPIKeyStep() {
        let bounds = contentView.bounds

        // Check if this provider needs an API key
        let needsKey: Bool
        switch selectedProvider {
        case .claude, .gemini, .codex: needsKey = true
        default: needsKey = false
        }

        if !needsKey {
            // Skip this step visually — show a simple confirmation
            let title = NSTextField(labelWithString: "No API Key Needed")
            title.font = .boldSystemFont(ofSize: 18)
            title.alignment = .center
            title.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 30)
            title.autoresizingMask = [.width]
            contentView.addSubview(title)

            let providerName: String
            switch selectedProvider {
            case .claudeCode: providerName = "Claude Code"
            case .codexCode: providerName = "Codex Code"
            case .copilot: providerName = "GitHub Copilot"
            default: providerName = selectedProvider.rawValue
            }

            let desc = NSTextField(wrappingLabelWithString:
                "\(providerName) uses a local CLI tool. No API key is needed.\n\nClick Next to continue.")
            desc.font = .systemFont(ofSize: 14)
            desc.alignment = .center
            desc.frame = NSRect(x: 40, y: bounds.height - 180, width: bounds.width - 80, height: 60)
            desc.autoresizingMask = [.width]
            contentView.addSubview(desc)

            addNavigationButtons(showBack: true)
            return
        }

        let title = NSTextField(labelWithString: "Enter your API Key")
        title.font = .boldSystemFont(ofSize: 18)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let keyLabel: String
        switch selectedProvider {
        case .claude: keyLabel = "Anthropic API Key:"
        case .gemini: keyLabel = "Gemini API Key:"
        case .codex: keyLabel = "OpenAI API Key:"
        default: keyLabel = "API Key:"
        }

        let label = NSTextField(labelWithString: keyLabel)
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 40, y: bounds.height - 130, width: bounds.width - 80, height: 20)
        label.autoresizingMask = [.width]
        contentView.addSubview(label)

        let field = NSSecureTextField(frame: NSRect(x: 40, y: bounds.height - 165, width: bounds.width - 80, height: 28))
        field.placeholderString = "sk-ant-... / AIzaSy... / sk-..."
        field.autoresizingMask = [.width]
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        if !apiKey.isEmpty {
            field.stringValue = apiKey
        }
        apiKeyField = field
        contentView.addSubview(field)

        let testBtn = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testBtn.bezelStyle = .rounded
        testBtn.frame = NSRect(x: 40, y: bounds.height - 210, width: 140, height: 28)
        testBtn.autoresizingMask = []
        testButton = testBtn
        contentView.addSubview(testBtn)

        let resultLabel = NSTextField(labelWithString: "")
        resultLabel.font = .systemFont(ofSize: 12)
        resultLabel.frame = NSRect(x: 190, y: bounds.height - 210, width: bounds.width - 230, height: 28)
        resultLabel.autoresizingMask = [.width]
        testResultLabel = resultLabel
        contentView.addSubview(resultLabel)

        let hint = NSTextField(wrappingLabelWithString:
            "Your API key is stored securely in the macOS Keychain — not in plaintext.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.frame = NSRect(x: 40, y: bounds.height - 270, width: bounds.width - 80, height: 40)
        hint.autoresizingMask = [.width]
        contentView.addSubview(hint)

        addNavigationButtons(showBack: true)
    }

    @objc private func testConnection() {
        guard let field = apiKeyField else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            testResultLabel?.stringValue = "Please enter an API key first."
            testResultLabel?.textColor = .systemRed
            return
        }

        apiKey = key
        testResultLabel?.stringValue = "Testing..."
        testResultLabel?.textColor = .secondaryLabelColor
        testButton?.isEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.performConnectionTest(provider: self.selectedProvider, key: key)

            DispatchQueue.main.async {
                self.testButton?.isEnabled = true
                if success {
                    self.testResultLabel?.stringValue = "Connection successful!"
                    self.testResultLabel?.textColor = .systemGreen
                } else {
                    self.testResultLabel?.stringValue = "Connection failed. Check your key."
                    self.testResultLabel?.textColor = .systemRed
                }
            }
        }
    }

    private func performConnectionTest(provider: Config.AIProvider, key: String) -> Bool {
        switch provider {
        case .claude:
            return CorrectMeApp.fetchAnthropicModels(apiKey: key) != nil
        case .gemini:
            return CorrectMeApp.fetchGeminiModels(apiKey: key) != nil
        case .codex:
            return CorrectMeApp.fetchOpenAIModels(apiKey: key) != nil
        default:
            return true
        }
    }

    // MARK: - Step 3: Accessibility

    private func renderAccessibilityStep() {
        let bounds = contentView.bounds

        let title = NSTextField(labelWithString: "Grant Accessibility Permission")
        title.font = .boldSystemFont(ofSize: 18)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let hasAccess = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        )

        let statusText: String
        let statusColor: NSColor
        if hasAccess {
            statusText = "Accessibility permission is granted."
            statusColor = .systemGreen
        } else {
            statusText = "Accessibility permission is not yet granted."
            statusColor = .systemOrange
        }

        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = statusColor
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 40, y: bounds.height - 130, width: bounds.width - 80, height: 20)
        statusLabel.autoresizingMask = [.width]
        contentView.addSubview(statusLabel)

        let desc = NSTextField(wrappingLabelWithString:
            "CorrectMe needs Accessibility permission to read and replace selected text in any app.\n\nClick the button below to open System Settings, then add CorrectMe (or your terminal app) to the Accessibility list.")
        desc.font = .systemFont(ofSize: 13)
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: bounds.height - 240, width: bounds.width - 80, height: 80)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        let openBtn = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibilitySettings))
        openBtn.bezelStyle = .rounded
        openBtn.frame = NSRect(x: (bounds.width - 180) / 2, y: bounds.height - 280, width: 180, height: 28)
        openBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(openBtn)

        let refreshBtn = NSButton(title: "Refresh Status", target: self, action: #selector(refreshAccessibility))
        refreshBtn.bezelStyle = .rounded
        refreshBtn.frame = NSRect(x: (bounds.width - 140) / 2, y: bounds.height - 316, width: 140, height: 28)
        refreshBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(refreshBtn)

        addNavigationButtons(showBack: true)
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func refreshAccessibility() {
        renderStep()
    }

    // MARK: - Step 4: Hotkey

    private var hotkeyDisplayLabel: NSTextField?

    private func renderHotkeyStep() {
        let bounds = contentView.bounds

        let title = NSTextField(labelWithString: "Set your Hotkey")
        title.font = .boldSystemFont(ofSize: 18)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 80, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "Choose a keyboard shortcut to trigger text correction. Select any text and press this hotkey to correct it.")
        desc.font = .systemFont(ofSize: 13)
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: bounds.height - 140, width: bounds.width - 80, height: 40)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        // Current hotkey display
        let currentLabel = NSTextField(labelWithString: selectedHotkey.displayName)
        currentLabel.font = .monospacedSystemFont(ofSize: 28, weight: .medium)
        currentLabel.alignment = .center
        currentLabel.frame = NSRect(x: 40, y: bounds.height - 200, width: bounds.width - 80, height: 40)
        currentLabel.autoresizingMask = [.width]
        hotkeyDisplayLabel = currentLabel
        contentView.addSubview(currentLabel)

        // Preset buttons
        let presets: [(label: String, keyCode: UInt16, modifiers: UInt64, display: String)] = [
            ("⌘⇧E", 14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
            ("⌘⇧C", 8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
            ("⌘⇧D", 2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
            ("⌘⇧S", 1, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧S"),
            ("⌃⇧E", 14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
        ]

        let btnWidth: CGFloat = 70
        let gap: CGFloat = 8
        let totalWidth = CGFloat(presets.count) * btnWidth + CGFloat(presets.count - 1) * gap
        var bx = (bounds.width - totalWidth) / 2

        for (i, preset) in presets.enumerated() {
            let btn = NSButton(title: preset.label, target: self, action: #selector(hotkeyPresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.tag = i
            btn.frame = NSRect(x: bx, y: bounds.height - 250, width: btnWidth, height: 28)
            btn.autoresizingMask = [.minXMargin, .maxXMargin]
            contentView.addSubview(btn)
            bx += btnWidth + gap
        }

        // Custom capture button
        let captureBtn = NSButton(title: "Capture Custom Hotkey...", target: self, action: #selector(captureCustomHotkey))
        captureBtn.bezelStyle = .rounded
        captureBtn.frame = NSRect(x: (bounds.width - 200) / 2, y: bounds.height - 290, width: 200, height: 28)
        captureBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(captureBtn)

        addNavigationButtons(showBack: true, nextLabel: "Finish")
    }

    @objc private func hotkeyPresetTapped(_ sender: NSButton) {
        let presets: [(keyCode: UInt16, modifiers: UInt64, display: String)] = [
            (14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
            (8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
            (2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
            (1, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧S"),
            (14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
        ]
        let preset = presets[sender.tag]
        selectedHotkey = Config.HotkeyConfig(keyCode: preset.keyCode, modifiers: preset.modifiers, displayName: preset.display)
        hotkeyDisplayLabel?.stringValue = preset.display
    }

    @objc private func captureCustomHotkey() {
        if let captured = CorrectMeApp.captureHotkey() {
            selectedHotkey = Config.HotkeyConfig(
                keyCode: captured.keyCode,
                modifiers: captured.modifiers,
                displayName: captured.displayName
            )
            hotkeyDisplayLabel?.stringValue = captured.displayName
        }
    }

    // MARK: - Done (step 5)

    private func renderDoneStep() {
        let bounds = contentView.bounds

        let icon = NSTextField(labelWithString: "🎉")
        icon.font = .systemFont(ofSize: 64)
        icon.alignment = .center
        icon.frame = NSRect(x: 0, y: bounds.height - 120, width: bounds.width, height: 80)
        icon.autoresizingMask = [.width]
        contentView.addSubview(icon)

        let title = NSTextField(labelWithString: "You're all set!")
        title.font = .boldSystemFont(ofSize: 22)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: bounds.height - 170, width: bounds.width - 40, height: 30)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "CorrectMe is configured and ready.\n\nSelect any text and press \(selectedHotkey.displayName) to correct it.\n\nYou can change settings anytime from the menu bar icon.")
        desc.font = .systemFont(ofSize: 14)
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: bounds.height - 280, width: bounds.width - 80, height: 100)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        let startBtn = NSButton(title: "Start CorrectMe", target: self, action: #selector(finishOnboarding))
        startBtn.bezelStyle = .rounded
        startBtn.keyEquivalent = "\r"
        startBtn.frame = NSRect(x: (bounds.width - 160) / 2, y: 60, width: 160, height: 32)
        startBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(startBtn)
    }

    @objc private func finishOnboarding() {
        window?.close()
        onComplete?()
    }

    // MARK: - Navigation

    private func addNavigationButtons(showBack: Bool, nextLabel: String = "Next") {
        let bounds = contentView.bounds

        let nextBtn = NSButton(title: nextLabel, target: self, action: #selector(nextStep))
        nextBtn.bezelStyle = .rounded
        nextBtn.keyEquivalent = "\r"
        nextBtn.frame = NSRect(x: bounds.width - 120, y: 16, width: 100, height: 28)
        nextBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(nextBtn)

        if showBack {
            let backBtn = NSButton(title: "Back", target: self, action: #selector(prevStep))
            backBtn.bezelStyle = .rounded
            backBtn.frame = NSRect(x: bounds.width - 230, y: 16, width: 100, height: 28)
            backBtn.autoresizingMask = [.minXMargin, .maxYMargin]
            contentView.addSubview(backBtn)
        }
    }

    @objc private func nextStep() {
        // Validate current step before proceeding
        if currentStep == 2 {
            // API key step — capture the key value
            if let field = apiKeyField {
                let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    apiKey = key
                }
            }

            // Validate key is provided for API providers
            let needsKey: Bool
            switch selectedProvider {
            case .claude, .gemini, .codex: needsKey = true
            default: needsKey = false
            }
            if needsKey && apiKey.isEmpty {
                let alert = NSAlert()
                alert.messageText = "API Key Required"
                alert.informativeText = "Please enter your API key before continuing."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
        }

        if currentStep == 4 {
            // Save config on the hotkey step (the last real step)
            saveOnboardingConfig()
            currentStep = 5
        } else {
            currentStep += 1
        }
        renderStep()
    }

    @objc private func prevStep() {
        // Capture API key when going back from step 2
        if currentStep == 2, let field = apiKeyField {
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                apiKey = key
            }
        }
        if currentStep > 0 {
            currentStep -= 1
            renderStep()
        }
    }

    // MARK: - Step indicator

    private func renderStepIndicator() {
        let bounds = contentView.bounds
        let steps = min(currentStep, totalSteps - 1)
        let indicatorY: CGFloat = 52

        for i in 0..<totalSteps {
            let dot = NSTextField(labelWithString: i <= steps ? "●" : "○")
            dot.font = .systemFont(ofSize: 12)
            dot.textColor = i <= steps ? .controlAccentColor : .tertiaryLabelColor
            dot.alignment = .center
            let dotWidth: CGFloat = 20
            let totalWidth = CGFloat(totalSteps) * dotWidth
            let startX = (bounds.width - totalWidth) / 2
            dot.frame = NSRect(x: startX + CGFloat(i) * dotWidth, y: indicatorY, width: dotWidth, height: 16)
            dot.autoresizingMask = [.minXMargin, .maxXMargin]
            contentView.addSubview(dot)
        }
    }

    // MARK: - Save

    private func saveOnboardingConfig() {
        var config = Config.default
        config.aiProvider = selectedProvider
        config.hotkey = selectedHotkey

        // Set default model
        switch selectedProvider {
        case .claudeCode: config.model = Config.DefaultModels.claudeCode
        case .codexCode: config.model = Config.DefaultModels.openaiCodex
        case .copilot: config.model = Config.DefaultModels.copilot
        case .claude: config.model = Config.DefaultModels.anthropic
        case .gemini: config.model = Config.DefaultModels.gemini
        case .codex: config.model = Config.DefaultModels.openaiCodex
        }

        // Set API key
        switch selectedProvider {
        case .claude: config.anthropicAPIKey = apiKey
        case .gemini: config.geminiAPIKey = apiKey
        case .codex: config.openaiAPIKey = apiKey
        default: break
        }

        do {
            try config.save()
            debugLog("Onboarding config saved successfully")
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to save configuration"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // If user closes without completing, still call completion
        // so the app continues running
        onComplete?()
        onComplete = nil
    }
}
