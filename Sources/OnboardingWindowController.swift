import Cocoa
import Foundation

/// NSWindow-based onboarding wizard shown on first launch (no config file present).
/// Steps: Welcome → Privacy → Choose Provider → Enter API Key → Accessibility → Hotkey → Done
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

    // Provider step views
    private var providerInfoBox: NSBox?

    // API key step views
    private var modelTextField: NSTextField?

    // MARK: - Provider Metadata

    private struct ProviderMeta {
        let description: String
        let recommendedModel: String
        let cost: String
        let badge: String?
    }

    private func providerMeta(for provider: Config.AIProvider) -> ProviderMeta {
        switch provider {
        case .claudeCode:
            let ok = findExecutable("claude") != nil
            return ProviderMeta(
                description: "Uses your installed Claude Code CLI — no API costs, works with your Claude subscription.",
                recommendedModel: Config.DefaultModels.claudeCode,
                cost: "Free (Claude subscription)",
                badge: ok ? "Installed ✓" : "CLI not found"
            )
        case .codexCode:
            let ok = findExecutable("codex") != nil
            return ProviderMeta(
                description: "Uses your installed Codex CLI — no API costs.",
                recommendedModel: Config.DefaultModels.openaiCodex,
                cost: "Free (local CLI)",
                badge: ok ? "Installed ✓" : "CLI not found"
            )
        case .copilot:
            let ok = findExecutable("gh") != nil
            return ProviderMeta(
                description: "Uses GitHub Copilot via the gh CLI. Requires a GitHub Copilot subscription.",
                recommendedModel: Config.DefaultModels.copilot,
                cost: "Free with Copilot subscription",
                badge: ok ? "Installed ✓" : "CLI not found"
            )
        case .claude:
            return ProviderMeta(
                description: "Direct Anthropic API. Excellent quality, very fast. claude-haiku is cheap and reliable for corrections.",
                recommendedModel: Config.DefaultModels.anthropic,
                cost: "~$0.001–0.01 / correction",
                badge: "Best Quality"
            )
        case .gemini:
            return ProviderMeta(
                description: "Google Gemini API. Good quality with a generous free tier — great for getting started.",
                recommendedModel: Config.DefaultModels.gemini,
                cost: "Free tier available",
                badge: "Free Tier"
            )
        case .codex:
            return ProviderMeta(
                description: "OpenAI API (GPT-based models). Fast and reliable for text corrections.",
                recommendedModel: Config.DefaultModels.openaiCodex,
                cost: "~$0.001 / correction",
                badge: nil
            )
        case .openrouter:
            return ProviderMeta(
                description: "Access 100+ models via OpenRouter — including free options. Great for experimenting.",
                recommendedModel: Config.DefaultModels.openrouter,
                cost: "Free models available",
                badge: "100+ Models"
            )
        }
    }

    private func bestAvailableProvider() -> Config.AIProvider {
        if findExecutable("claude") != nil { return .claudeCode }
        if findExecutable("codex") != nil { return .codexCode }
        if findExecutable("gh") != nil { return .copilot }
        return .claude
    }

    private var currentStep = 0
    private let totalSteps = 6 // 0..5

    // Layout constants
    private let windowWidth: CGFloat = 560
    private let windowHeight: CGFloat = 480
    private let contentPad: CGFloat = 40

    // MARK: - Show

    func show(completion: @escaping () -> Void) {
        onComplete = completion

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to CorrectMe"
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.backgroundColor = .windowBackgroundColor

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
        case 1: renderPrivacyStep()
        case 2: renderProviderStep()
        case 3: renderAPIKeyStep()
        case 4: renderAccessibilityStep()
        case 5: renderHotkeyStep()
        default: renderDoneStep()
        }

        renderStepIndicator()
    }

    // MARK: - Helpers

    private func makeSFSymbol(_ name: String, size: CGFloat, color: NSColor? = nil) -> NSImageView {
        let imageView = NSImageView()
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .light)
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                imageView.image = image
                if let color = color {
                    imageView.contentTintColor = color
                }
            }
        }
        imageView.imageScaling = .scaleProportionallyDown
        return imageView
    }

    private func makeTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }

    private func makeSubtitle(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        return label
    }

    private func makeAccentButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: target, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .large
        btn.keyEquivalent = "\r"
        btn.font = .systemFont(ofSize: 14, weight: .medium)
        return btn
    }

    private func makeSecondaryButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: target, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .large
        btn.font = .systemFont(ofSize: 14)
        return btn
    }

    // MARK: - Step 0: Welcome

    private func renderWelcome() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        // SF Symbol icon
        let icon = makeSFSymbol("pencil.and.outline", size: 56, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 40, y: bounds.height - 130, width: 80, height: 80)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Welcome to CorrectMe")
        title.frame = NSRect(x: contentPad, y: bounds.height - 180, width: bounds.width - contentPad * 2, height: 32)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = makeSubtitle("Select any text, press a hotkey, and get instant AI-powered corrections. Let's set it up in a few quick steps.")
        desc.frame = NSRect(x: contentPad + 20, y: bounds.height - 260, width: bounds.width - contentPad * 2 - 40, height: 60)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        // Feature highlights
        let features: [(icon: String, text: String)] = [
            ("bolt.fill", "Instant corrections with a single hotkey"),
            ("globe", "Works with any text field on your Mac"),
            ("lock.shield.fill", "Private — your data stays local"),
        ]

        let featureStartY = bounds.height - 300
        for (i, feature) in features.enumerated() {
            let y = featureStartY - CGFloat(i) * 32
            let fIcon = makeSFSymbol(feature.icon, size: 14, color: .secondaryLabelColor)
            fIcon.frame = NSRect(x: contentPad + 40, y: y, width: 20, height: 20)
            contentView.addSubview(fIcon)

            let fLabel = NSTextField(labelWithString: feature.text)
            fLabel.font = .systemFont(ofSize: 13)
            fLabel.textColor = .secondaryLabelColor
            fLabel.frame = NSRect(x: contentPad + 68, y: y, width: bounds.width - contentPad * 2 - 88, height: 20)
            fLabel.autoresizingMask = [.width]
            contentView.addSubview(fLabel)
        }

        addNavigationButtons(showBack: false, nextLabel: "Get Started")
    }

    // MARK: - Step 1: Privacy & Data

    private func renderPrivacyStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let icon = makeSFSymbol("lock.shield.fill", size: 44, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Privacy & Data Handling")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        // Privacy items with SF Symbols
        let items: [(icon: String, text: String)] = [
            ("arrow.up.circle", "Your selected text is sent to your chosen AI provider — only for correction. No other data is transmitted."),
            ("internaldrive", "CorrectMe does not store or share your text remotely. Correction history is kept locally on your Mac."),
            ("key.fill", "API keys are stored securely in the macOS Keychain."),
            ("eye.slash.fill", "No analytics, telemetry, or tracking is collected."),
        ]

        let startY = bounds.height - 195
        var y = startY
        for item in items {
            let itemIcon = makeSFSymbol(item.icon, size: 14, color: .tertiaryLabelColor)
            itemIcon.frame = NSRect(x: contentPad, y: y, width: 20, height: 20)
            contentView.addSubview(itemIcon)

            let itemLabel = NSTextField(wrappingLabelWithString: item.text)
            itemLabel.font = .systemFont(ofSize: 12)
            itemLabel.textColor = .secondaryLabelColor
            itemLabel.frame = NSRect(x: contentPad + 28, y: y - 16, width: bounds.width - contentPad * 2 - 28, height: 36)
            itemLabel.autoresizingMask = [.width]
            contentView.addSubview(itemLabel)

            y -= 48
        }

        let linkBtn = NSButton(title: "View Privacy Policy", target: self, action: #selector(openPrivacyPolicy))
        linkBtn.bezelStyle = .accessoryBarAction
        linkBtn.frame = NSRect(x: (bounds.width - 160) / 2, y: y - 8, width: 160, height: 24)
        linkBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(linkBtn)

        let consentLabel = NSTextField(labelWithString: "By clicking Next, you acknowledge this data handling.")
        consentLabel.font = .systemFont(ofSize: 11)
        consentLabel.textColor = .tertiaryLabelColor
        consentLabel.alignment = .center
        consentLabel.frame = NSRect(x: contentPad, y: y - 34, width: bounds.width - contentPad * 2, height: 16)
        consentLabel.autoresizingMask = [.width]
        contentView.addSubview(consentLabel)

        addNavigationButtons(showBack: true)
    }

    @objc private func openPrivacyPolicy() {
        if let url = URL(string: "https://github.com/tamcv/correct_me/blob/main/PRIVACY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Step 2: Choose Provider

    private var providerPopup: NSPopUpButton?

    private func renderProviderStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let icon = makeSFSymbol("cpu", size: 44, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Choose your AI Provider")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let providerLabel = makeSectionLabel("Provider")
        providerLabel.frame = NSRect(x: contentPad, y: bounds.height - 185, width: 100, height: 18)
        contentView.addSubview(providerLabel)

        // Auto-select best available provider on first render of this step
        if selectedProvider == .claudeCode {
            selectedProvider = bestAvailableProvider()
        }

        let allProviders: [(Config.AIProvider, String)] = [
            (.claudeCode, "Claude Code  —  local CLI"),
            (.codexCode,  "Codex Code  —  local CLI"),
            (.copilot,    "GitHub Copilot  —  local CLI"),
            (.claude,     "Claude API  —  key required"),
            (.gemini,     "Gemini API  —  key required"),
            (.codex,      "OpenAI / Codex API  —  key required"),
            (.openrouter, "OpenRouter API  —  key required"),
        ]

        let popup = NSPopUpButton(frame: NSRect(x: contentPad, y: bounds.height - 215, width: bounds.width - contentPad * 2, height: 26))
        popup.autoresizingMask = [.width]
        popup.controlSize = .large
        for (_, label) in allProviders { popup.addItem(withTitle: label) }
        if let idx = allProviders.firstIndex(where: { $0.0 == selectedProvider }) {
            popup.selectItem(at: idx)
        }
        popup.target = self
        popup.action = #selector(providerChanged(_:))
        providerPopup = popup
        contentView.addSubview(popup)

        // Info card — shows description, recommended model, cost
        let infoBox = NSBox()
        infoBox.boxType = .custom
        infoBox.fillColor = NSColor.controlBackgroundColor
        infoBox.borderColor = .separatorColor
        infoBox.borderWidth = 1
        infoBox.cornerRadius = 8
        infoBox.frame = NSRect(x: contentPad, y: bounds.height - 370, width: bounds.width - contentPad * 2, height: 130)
        infoBox.autoresizingMask = [.width]
        contentView.addSubview(infoBox)
        providerInfoBox = infoBox

        updateProviderInfoCard()
        addNavigationButtons(showBack: true)
    }

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        let providers: [Config.AIProvider] = [.claudeCode, .codexCode, .copilot, .claude, .gemini, .codex, .openrouter]
        selectedProvider = providers[sender.indexOfSelectedItem]
        // Reset selected model so the new provider's default is picked up
        selectedModel = nil
        updateProviderInfoCard()
    }

    private func updateProviderInfoCard() {
        guard let box = providerInfoBox else { return }
        box.subviews.forEach { $0.removeFromSuperview() }

        let meta = providerMeta(for: selectedProvider)
        let bw = box.frame.width

        // Badge (top-right)
        if let badge = meta.badge {
            let isCLIWarning = badge.contains("not found")
            let badgeLabel = NSTextField(labelWithString: badge)
            badgeLabel.font = .systemFont(ofSize: 10, weight: .medium)
            badgeLabel.textColor = isCLIWarning ? .systemOrange : .systemGreen
            badgeLabel.alignment = .right
            badgeLabel.frame = NSRect(x: bw - 150, y: 102, width: 138, height: 16)
            box.addSubview(badgeLabel)
        }

        // Description
        let desc = NSTextField(wrappingLabelWithString: meta.description)
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        desc.frame = NSRect(x: 12, y: 54, width: bw - 24, height: 62)
        box.addSubview(desc)

        // Divider
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 12, y: 48, width: bw - 24, height: 1)
        box.addSubview(sep)

        // Model row
        let modelKeyLabel = NSTextField(labelWithString: "Recommended model:")
        modelKeyLabel.font = .systemFont(ofSize: 11)
        modelKeyLabel.textColor = .tertiaryLabelColor
        modelKeyLabel.frame = NSRect(x: 12, y: 26, width: 140, height: 16)
        box.addSubview(modelKeyLabel)

        let modelVal = NSTextField(labelWithString: meta.recommendedModel)
        modelVal.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        modelVal.textColor = .controlAccentColor
        modelVal.frame = NSRect(x: 156, y: 26, width: bw - 260, height: 16)
        box.addSubview(modelVal)

        // Cost (right-aligned on model row)
        let costLabel = NSTextField(labelWithString: meta.cost)
        costLabel.font = .systemFont(ofSize: 10)
        costLabel.textColor = .tertiaryLabelColor
        costLabel.alignment = .right
        costLabel.frame = NSRect(x: bw - 160, y: 26, width: 148, height: 16)
        box.addSubview(costLabel)

        // Model note
        let modelNote = NSTextField(labelWithString: "You can change the model after setup in Preferences.")
        modelNote.font = .systemFont(ofSize: 10)
        modelNote.textColor = .tertiaryLabelColor
        modelNote.frame = NSRect(x: 12, y: 8, width: bw - 24, height: 14)
        box.addSubview(modelNote)
    }

    // MARK: - Step 3: API Key

    private var apiKeyField: NSSecureTextField?
    private var testResultLabel: NSTextField?
    private var testButton: NSButton?

    private func renderAPIKeyStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let needsKey: Bool
        switch selectedProvider {
        case .claude, .gemini, .codex, .openrouter: needsKey = true
        default: needsKey = false
        }

        if !needsKey {
            let icon = makeSFSymbol("checkmark.circle.fill", size: 44, color: .systemGreen)
            icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
            icon.autoresizingMask = [.minXMargin, .maxXMargin]
            contentView.addSubview(icon)

            let title = makeTitle("No API Key Needed")
            title.font = .systemFont(ofSize: 20, weight: .bold)
            title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
            title.autoresizingMask = [.width]
            contentView.addSubview(title)

            let providerName: String
            switch selectedProvider {
            case .claudeCode: providerName = "Claude Code"
            case .codexCode: providerName = "Codex Code"
            case .copilot: providerName = "GitHub Copilot"
            default: providerName = selectedProvider.rawValue
            }

            let desc = makeSubtitle("\(providerName) uses a local CLI — no API key needed.")
            desc.frame = NSRect(x: contentPad + 20, y: bounds.height - 190, width: bounds.width - contentPad * 2 - 40, height: 24)
            desc.autoresizingMask = [.width]
            contentView.addSubview(desc)

            // Still show model field for CLI providers
            addModelField(at: bounds.height - 250, in: bounds)
            addNavigationButtons(showBack: true)
            return
        }

        let icon = makeSFSymbol("key.fill", size: 44, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Enter your API Key")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let keyLabel: String
        switch selectedProvider {
        case .claude:      keyLabel = "Anthropic API Key"
        case .gemini:      keyLabel = "Google Gemini API Key"
        case .codex:       keyLabel = "OpenAI API Key"
        case .openrouter:  keyLabel = "OpenRouter API Key"
        default:           keyLabel = "API Key"
        }

        let label = makeSectionLabel(keyLabel)
        label.frame = NSRect(x: contentPad, y: bounds.height - 190, width: bounds.width - contentPad * 2, height: 18)
        label.autoresizingMask = [.width]
        contentView.addSubview(label)

        let field = NSSecureTextField(frame: NSRect(x: contentPad, y: bounds.height - 220, width: bounds.width - contentPad * 2, height: 28))
        field.placeholderString = "sk-ant-... / AIzaSy... / sk-..."
        field.autoresizingMask = [.width]
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.controlSize = .large
        if !apiKey.isEmpty { field.stringValue = apiKey }
        apiKeyField = field
        contentView.addSubview(field)

        let testBtn = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testBtn.bezelStyle = .rounded
        testBtn.frame = NSRect(x: contentPad, y: bounds.height - 258, width: 140, height: 28)
        testButton = testBtn
        contentView.addSubview(testBtn)

        let resultLabel = NSTextField(labelWithString: "")
        resultLabel.font = .systemFont(ofSize: 12)
        resultLabel.frame = NSRect(x: contentPad + 148, y: bounds.height - 258, width: bounds.width - contentPad * 2 - 148, height: 28)
        resultLabel.autoresizingMask = [.width]
        testResultLabel = resultLabel
        contentView.addSubview(resultLabel)

        let keychainIcon = makeSFSymbol("lock.fill", size: 11, color: .tertiaryLabelColor)
        keychainIcon.frame = NSRect(x: contentPad, y: bounds.height - 286, width: 16, height: 16)
        contentView.addSubview(keychainIcon)

        let hint = NSTextField(labelWithString: "Stored securely in the macOS Keychain — never in plaintext.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: contentPad + 20, y: bounds.height - 286, width: bounds.width - contentPad * 2 - 20, height: 16)
        hint.autoresizingMask = [.width]
        contentView.addSubview(hint)

        addModelField(at: bounds.height - 350, in: bounds)
        addNavigationButtons(showBack: true)
    }

    private func addModelField(at y: CGFloat, in bounds: NSRect) {
        let modelLabel = makeSectionLabel("Model")
        modelLabel.frame = NSRect(x: contentPad, y: y, width: 80, height: 18)
        contentView.addSubview(modelLabel)

        let recommended = providerMeta(for: selectedProvider).recommendedModel

        let field = NSTextField(frame: NSRect(x: contentPad, y: y - 30, width: bounds.width - contentPad * 2, height: 26))
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.stringValue = selectedModel ?? recommended
        field.placeholderString = recommended
        field.controlSize = .regular
        modelTextField = field
        contentView.addSubview(field)

        let hint = NSTextField(labelWithString: "Pre-filled with the recommended model. Change if needed.")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: contentPad, y: y - 48, width: bounds.width - contentPad * 2, height: 14)
        hint.autoresizingMask = [.width]
        contentView.addSubview(hint)
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
                    self.testResultLabel?.stringValue = "✓ Connection successful!"
                    self.testResultLabel?.textColor = .systemGreen
                } else {
                    self.testResultLabel?.stringValue = "✕ Connection failed. Check your key."
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
        case .openrouter:
            return CorrectMeApp.fetchOpenRouterModels(apiKey: key) != nil
        default:
            return true
        }
    }

    // MARK: - Step 4: Accessibility

    private func renderAccessibilityStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let icon = makeSFSymbol("hand.raised.fill", size: 44, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Accessibility Permission")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let hasAccess = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        )

        // Status badge
        let statusBg = NSView()
        statusBg.wantsLayer = true
        statusBg.layer?.cornerRadius = 8

        let statusIcon: String
        let statusText: String
        let statusColor: NSColor
        if hasAccess {
            statusIcon = "checkmark.circle.fill"
            statusText = "Permission granted"
            statusColor = .systemGreen
            statusBg.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
        } else {
            statusIcon = "exclamationmark.triangle.fill"
            statusText = "Permission required"
            statusColor = .systemOrange
            statusBg.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.1).cgColor
        }

        let badgeWidth: CGFloat = 220
        statusBg.frame = NSRect(x: (bounds.width - badgeWidth) / 2, y: bounds.height - 200, width: badgeWidth, height: 32)
        statusBg.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(statusBg)

        let sIcon = makeSFSymbol(statusIcon, size: 14, color: statusColor)
        sIcon.frame = NSRect(x: 10, y: 6, width: 20, height: 20)
        statusBg.addSubview(sIcon)

        let sLabel = NSTextField(labelWithString: statusText)
        sLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sLabel.textColor = statusColor
        sLabel.frame = NSRect(x: 34, y: 6, width: badgeWidth - 44, height: 20)
        statusBg.addSubview(sLabel)

        let desc = makeSubtitle("CorrectMe needs Accessibility permission to read and replace selected text in any app.\n\nOpen System Settings and add CorrectMe (or your terminal app) to the Accessibility list.")
        desc.frame = NSRect(x: contentPad, y: bounds.height - 310, width: bounds.width - contentPad * 2, height: 80)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        let openBtn = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibilitySettings))
        openBtn.bezelStyle = .rounded
        openBtn.controlSize = .large
        openBtn.frame = NSRect(x: (bounds.width - 200) / 2, y: bounds.height - 350, width: 200, height: 32)
        openBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(openBtn)

        let refreshBtn = NSButton(title: "Refresh Status", target: self, action: #selector(refreshAccessibility))
        refreshBtn.bezelStyle = .accessoryBarAction
        refreshBtn.frame = NSRect(x: (bounds.width - 120) / 2, y: bounds.height - 382, width: 120, height: 24)
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

    // MARK: - Step 5: Hotkey

    private var hotkeyDisplayLabel: NSTextField?

    private func renderHotkeyStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let icon = makeSFSymbol("keyboard", size: 44, color: .controlAccentColor)
        icon.frame = NSRect(x: cx - 30, y: bounds.height - 110, width: 60, height: 60)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("Set your Hotkey")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.frame = NSRect(x: contentPad, y: bounds.height - 150, width: bounds.width - contentPad * 2, height: 28)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = makeSubtitle("Choose a keyboard shortcut to trigger text correction.")
        desc.frame = NSRect(x: contentPad, y: bounds.height - 182, width: bounds.width - contentPad * 2, height: 20)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        // Current hotkey display — styled like a key cap
        let keyCapBg = NSView()
        keyCapBg.wantsLayer = true
        keyCapBg.layer?.cornerRadius = 12
        keyCapBg.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keyCapBg.layer?.borderWidth = 1
        keyCapBg.layer?.borderColor = NSColor.separatorColor.cgColor
        let keyCapWidth: CGFloat = 180
        keyCapBg.frame = NSRect(x: (bounds.width - keyCapWidth) / 2, y: bounds.height - 248, width: keyCapWidth, height: 52)
        keyCapBg.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(keyCapBg)

        let currentLabel = NSTextField(labelWithString: selectedHotkey.displayName)
        currentLabel.font = .monospacedSystemFont(ofSize: 28, weight: .medium)
        currentLabel.alignment = .center
        currentLabel.textColor = .labelColor
        currentLabel.frame = NSRect(x: 0, y: 6, width: keyCapWidth, height: 40)
        keyCapBg.addSubview(currentLabel)
        hotkeyDisplayLabel = currentLabel

        // Preset buttons
        let presets: [(label: String, keyCode: UInt16, modifiers: UInt64, display: String)] = [
            ("⌘⇧E", 14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
            ("⌘⇧C", 8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
            ("⌘⇧D", 2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
            ("⌘⇧S", 1, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧S"),
            ("⌃⇧E", 14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
        ]

        let btnWidth: CGFloat = 60
        let gap: CGFloat = 10
        let totalWidth = CGFloat(presets.count) * btnWidth + CGFloat(presets.count - 1) * gap
        var bx = (bounds.width - totalWidth) / 2

        for (i, preset) in presets.enumerated() {
            let btn = NSButton(title: preset.label, target: self, action: #selector(hotkeyPresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.tag = i
            btn.frame = NSRect(x: bx, y: bounds.height - 300, width: btnWidth, height: 28)
            btn.autoresizingMask = [.minXMargin, .maxXMargin]
            contentView.addSubview(btn)
            bx += btnWidth + gap
        }

        // Custom capture button
        let captureBtn = NSButton(title: "Record Custom Hotkey…", target: self, action: #selector(captureCustomHotkey))
        captureBtn.bezelStyle = .rounded
        captureBtn.frame = NSRect(x: (bounds.width - 200) / 2, y: bounds.height - 340, width: 200, height: 28)
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

    // MARK: - Done (step 6)

    private func renderDoneStep() {
        let bounds = contentView.bounds
        let cx = bounds.width / 2

        let icon = makeSFSymbol("checkmark.circle.fill", size: 56, color: .systemGreen)
        icon.frame = NSRect(x: cx - 40, y: bounds.height - 130, width: 80, height: 80)
        icon.autoresizingMask = [.minXMargin, .maxXMargin]
        contentView.addSubview(icon)

        let title = makeTitle("You're all set!")
        title.frame = NSRect(x: contentPad, y: bounds.height - 180, width: bounds.width - contentPad * 2, height: 32)
        title.autoresizingMask = [.width]
        contentView.addSubview(title)

        let desc = makeSubtitle("CorrectMe is configured and ready.\n\nSelect any text and press \(selectedHotkey.displayName) to correct it.\nYou can change settings anytime from the menu bar icon.")
        desc.frame = NSRect(x: contentPad + 20, y: bounds.height - 280, width: bounds.width - contentPad * 2 - 40, height: 80)
        desc.autoresizingMask = [.width]
        contentView.addSubview(desc)

        let startBtn = makeAccentButton("Start CorrectMe", target: self, action: #selector(finishOnboarding))
        startBtn.frame = NSRect(x: (bounds.width - 180) / 2, y: 70, width: 180, height: 36)
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

        let nextBtn = makeAccentButton(nextLabel, target: self, action: #selector(nextStep))
        nextBtn.frame = NSRect(x: bounds.width - contentPad - 110, y: 16, width: 110, height: 32)
        nextBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(nextBtn)

        if showBack {
            let backBtn = makeSecondaryButton("Back", target: self, action: #selector(prevStep))
            backBtn.keyEquivalent = ""
            backBtn.frame = NSRect(x: bounds.width - contentPad - 230, y: 16, width: 110, height: 32)
            backBtn.autoresizingMask = [.minXMargin, .maxYMargin]
            contentView.addSubview(backBtn)
        }
    }

    @objc private func nextStep() {
        // Validate current step before proceeding
        if currentStep == 3 {
            // Capture API key
            if let field = apiKeyField {
                let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty { apiKey = key }
            }

            // Capture model override
            if let field = modelTextField {
                let val = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                selectedModel = val.isEmpty ? nil : val
            }

            // Validate key is provided for API providers
            let needsKey: Bool
            switch selectedProvider {
            case .claude, .gemini, .codex, .openrouter: needsKey = true
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

        if currentStep == 5 {
            // Save config on the hotkey step (the last real step)
            saveOnboardingConfig()
            currentStep = 6
        } else {
            currentStep += 1
        }
        renderStep()
    }

    @objc private func prevStep() {
        if currentStep == 3 {
            if let field = apiKeyField {
                let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty { apiKey = key }
            }
            if let field = modelTextField {
                let val = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                selectedModel = val.isEmpty ? nil : val
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
        let indicatorY: CGFloat = 56

        // Progress bar style indicator
        let totalWidth: CGFloat = CGFloat(totalSteps - 1) * 40
        let startX = (bounds.width - totalWidth) / 2

        for i in 0..<totalSteps {
            // Dot
            let dotSize: CGFloat = i <= steps ? 10 : 8
            let dotY = indicatorY + (10 - dotSize) / 2
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2

            if i < steps {
                dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            } else if i == steps {
                dot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            } else {
                dot.layer?.backgroundColor = NSColor.separatorColor.cgColor
            }

            dot.frame = NSRect(
                x: startX + CGFloat(i) * 40 - dotSize / 2,
                y: dotY,
                width: dotSize,
                height: dotSize
            )
            dot.autoresizingMask = [.minXMargin, .maxXMargin]
            contentView.addSubview(dot)

            // Connecting line
            if i < totalSteps - 1 {
                let line = NSView()
                line.wantsLayer = true
                line.layer?.backgroundColor = (i < steps ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
                line.frame = NSRect(
                    x: startX + CGFloat(i) * 40 + dotSize / 2,
                    y: indicatorY + 4,
                    width: 40 - dotSize,
                    height: 2
                )
                line.autoresizingMask = [.minXMargin, .maxXMargin]
                contentView.addSubview(line)
            }
        }
    }

    // MARK: - Save

    private func saveOnboardingConfig() {
        var config = Config.default
        config.aiProvider = selectedProvider
        config.hotkey = selectedHotkey

        // Use model chosen by user in step 3, or fall back to the recommended default
        config.model = selectedModel ?? providerMeta(for: selectedProvider).recommendedModel

        // Set API key
        switch selectedProvider {
        case .claude: config.anthropicAPIKey = apiKey
        case .gemini: config.geminiAPIKey = apiKey
        case .codex: config.openaiAPIKey = apiKey
        case .openrouter: config.openrouterAPIKey = apiKey
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
