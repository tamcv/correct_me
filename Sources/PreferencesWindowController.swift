import AppKit
import CoreGraphics

/// Full Preferences window with tabs: General, Provider, Hotkey, Writing Style, Advanced.
class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSPanel?
    private var tabView: NSTabView!

    // ── State (loaded from Config on show, written on Save) ──
    private var config: Config = .default

    // Provider tab
    private var providerPopUp: NSPopUpButton!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    private var testResultLabel: NSTextField!
    private var testButton: NSButton!
    private var apiKeyLabel: NSTextField!
    private var apiKeyHint: NSTextField!

    // Hotkey tab
    private var hotkeyDisplayLabel: NSTextField!

    // Writing Style tab
    private var styleTextView: NSTextView!
    private var stylePlaceholder: NSTextField!

    // Per-app styles
    private var perAppStylesContainer: NSView!
    private var perAppEntries: [(bundleId: String, style: String)] = []

    // General tab
    private var autoStartCheckbox: NSButton!

    private let W: CGFloat = 520
    private let H: CGFloat = 540
    private let pad: CGFloat = 20

    private override init() { super.init() }

    // MARK: - Show

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        config = Config.load()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Preferences"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        let root = NSView(frame: panel.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        panel.contentView = root

        // Tab view
        tabView = NSTabView(frame: NSRect(x: 0, y: 44, width: W, height: H - 44))
        tabView.autoresizingMask = [.width, .height]
        root.addSubview(tabView)

        tabView.addTabViewItem(makeGeneralTab())
        tabView.addTabViewItem(makeProviderTab())
        tabView.addTabViewItem(makeHotkeyTab())
        tabView.addTabViewItem(makeWritingStyleTab())
        tabView.addTabViewItem(makeAdvancedTab())

        // Bottom buttons
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: W - pad - 80, y: 10, width: 80, height: 28)
        saveBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        root.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: W - pad - 170, y: 10, width: 80, height: 28)
        cancelBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        root.addSubview(cancelBtn)

        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "general")
        item.label = "General"
        let view = NSView()

        let y0: CGFloat = 280

        // Auto-start checkbox
        autoStartCheckbox = NSButton(checkboxWithTitle: "Start CorrectMe at login", target: nil, action: nil)
        autoStartCheckbox.frame = NSRect(x: pad, y: y0, width: 300, height: 20)
        autoStartCheckbox.state = DaemonManager.isLaunchAgentInstalled ? .on : .off
        view.addSubview(autoStartCheckbox)

        // Current hotkey
        let hkLabel = NSTextField(labelWithString: "Current hotkey:")
        hkLabel.frame = NSRect(x: pad, y: y0 - 40, width: 120, height: 20)
        hkLabel.font = .systemFont(ofSize: 13)
        view.addSubview(hkLabel)

        let hkValue = NSTextField(labelWithString: config.hotkey.displayName)
        hkValue.frame = NSRect(x: 140, y: y0 - 40, width: 200, height: 20)
        hkValue.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(hkValue)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: y0 - 70, width: W - pad * 2, height: 1)
        view.addSubview(sep)

        // Version
        let versionLabel = NSTextField(labelWithString: "Version: \(AppVersion.fullVersion)")
        versionLabel.frame = NSRect(x: pad, y: y0 - 100, width: 300, height: 20)
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        view.addSubview(versionLabel)

        // Provider info
        let providerLabel = NSTextField(labelWithString: "Provider: \(config.aiProvider.rawValue)")
        providerLabel.frame = NSRect(x: pad, y: y0 - 125, width: 300, height: 20)
        providerLabel.font = .systemFont(ofSize: 12)
        providerLabel.textColor = .secondaryLabelColor
        view.addSubview(providerLabel)

        item.view = view
        return item
    }

    // MARK: - Provider Tab

    private func makeProviderTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "provider")
        item.label = "Provider"
        let view = NSView()

        let y0: CGFloat = 280

        // Provider dropdown
        let pLabel = NSTextField(labelWithString: "AI Provider:")
        pLabel.frame = NSRect(x: pad, y: y0, width: 100, height: 20)
        pLabel.font = .systemFont(ofSize: 13)
        view.addSubview(pLabel)

        providerPopUp = NSPopUpButton(frame: NSRect(x: 120, y: y0 - 3, width: 200, height: 26), pullsDown: false)
        let providers: [(label: String, value: Config.AIProvider)] = [
            ("Claude Code (CLI)", .claudeCode),
            ("Codex Code (CLI)", .codexCode),
            ("GitHub Copilot (CLI)", .copilot),
            ("Claude API", .claude),
            ("Gemini API", .gemini),
            ("OpenAI/Codex API", .codex),
        ]
        for p in providers {
            providerPopUp.addItem(withTitle: p.label)
            providerPopUp.lastItem?.representedObject = p.value.rawValue
        }
        // Select current
        for i in 0..<providers.count {
            if providers[i].value == config.aiProvider {
                providerPopUp.selectItem(at: i)
                break
            }
        }
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged)
        view.addSubview(providerPopUp)

        // API Key
        apiKeyLabel = NSTextField(labelWithString: "API Key:")
        apiKeyLabel.frame = NSRect(x: pad, y: y0 - 45, width: 100, height: 20)
        apiKeyLabel.font = .systemFont(ofSize: 13)
        view.addSubview(apiKeyLabel)

        apiKeyField = NSSecureTextField(frame: NSRect(x: 120, y: y0 - 47, width: W - 140 - pad, height: 24))
        apiKeyField.placeholderString = "sk-ant-... / AIzaSy... / sk-..."
        apiKeyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        view.addSubview(apiKeyField)

        // Load current API key for the selected provider
        loadAPIKeyForCurrentProvider()

        // Test button
        testButton = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testButton.bezelStyle = .rounded
        testButton.frame = NSRect(x: 120, y: y0 - 82, width: 140, height: 28)
        view.addSubview(testButton)

        testResultLabel = NSTextField(labelWithString: "")
        testResultLabel.frame = NSRect(x: 270, y: y0 - 82, width: W - 270 - pad, height: 28)
        testResultLabel.font = .systemFont(ofSize: 12)
        view.addSubview(testResultLabel)

        // Model
        let mLabel = NSTextField(labelWithString: "Model:")
        mLabel.frame = NSRect(x: pad, y: y0 - 120, width: 100, height: 20)
        mLabel.font = .systemFont(ofSize: 13)
        view.addSubview(mLabel)

        modelField = NSTextField(frame: NSRect(x: 120, y: y0 - 122, width: W - 140 - pad, height: 24))
        modelField.placeholderString = defaultModelForProvider(config.aiProvider)
        modelField.stringValue = config.model ?? ""
        modelField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        view.addSubview(modelField)

        // Hint
        apiKeyHint = NSTextField(wrappingLabelWithString: "")
        apiKeyHint.frame = NSRect(x: 120, y: y0 - 175, width: W - 140 - pad, height: 36)
        apiKeyHint.font = .systemFont(ofSize: 11)
        apiKeyHint.textColor = .secondaryLabelColor
        view.addSubview(apiKeyHint)

        updateProviderUI()

        item.view = view
        return item
    }

    @objc private func providerChanged() {
        updateProviderUI()
    }

    private func selectedProvider() -> Config.AIProvider {
        guard let raw = providerPopUp.selectedItem?.representedObject as? String,
              let provider = Config.AIProvider(rawValue: raw) else {
            return .claudeCode
        }
        return provider
    }

    private func providerNeedsAPIKey(_ provider: Config.AIProvider) -> Bool {
        switch provider {
        case .claude, .gemini, .codex: return true
        case .claudeCode, .codexCode, .copilot: return false
        }
    }

    private func updateProviderUI() {
        let provider = selectedProvider()
        let needsKey = providerNeedsAPIKey(provider)

        apiKeyField.isEnabled = needsKey
        apiKeyLabel.textColor = needsKey ? .labelColor : .tertiaryLabelColor
        testButton.isEnabled = needsKey

        if needsKey {
            apiKeyHint.stringValue = "Your API key is stored securely in the macOS Keychain."
        } else {
            apiKeyHint.stringValue = "This provider uses a local CLI tool. No API key needed."
            apiKeyField.stringValue = ""
        }

        modelField.placeholderString = defaultModelForProvider(provider)
        testResultLabel.stringValue = ""

        loadAPIKeyForCurrentProvider()
    }

    private func loadAPIKeyForCurrentProvider() {
        let provider = selectedProvider()
        guard providerNeedsAPIKey(provider) else {
            apiKeyField.stringValue = ""
            return
        }

        switch provider {
        case .claude:
            apiKeyField.stringValue = config.anthropicAPIKey ?? ""
        case .gemini:
            apiKeyField.stringValue = config.geminiAPIKey ?? ""
        case .codex:
            apiKeyField.stringValue = config.openaiAPIKey ?? ""
        default:
            apiKeyField.stringValue = ""
        }
    }

    private func defaultModelForProvider(_ provider: Config.AIProvider) -> String {
        switch provider {
        case .claudeCode: return Config.DefaultModels.claudeCode
        case .claude: return Config.DefaultModels.anthropic
        case .gemini: return Config.DefaultModels.gemini
        case .codex: return Config.DefaultModels.openaiCodex
        case .codexCode: return Config.DefaultModels.openaiCodex
        case .copilot: return Config.DefaultModels.copilot
        }
    }

    @objc private func testConnection() {
        let provider = selectedProvider()
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            testResultLabel.stringValue = "Enter an API key first."
            testResultLabel.textColor = .systemRed
            return
        }

        testResultLabel.stringValue = "Testing..."
        testResultLabel.textColor = .secondaryLabelColor
        testButton.isEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.performConnectionTest(provider: provider, key: key) ?? false

            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                if success {
                    self?.testResultLabel.stringValue = "Connection successful!"
                    self?.testResultLabel.textColor = .systemGreen
                } else {
                    self?.testResultLabel.stringValue = "Connection failed. Check your key."
                    self?.testResultLabel.textColor = .systemRed
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

    // MARK: - Hotkey Tab

    private func makeHotkeyTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "hotkey")
        item.label = "Hotkey"
        let view = NSView()

        let y0: CGFloat = 280

        let desc = NSTextField(wrappingLabelWithString:
            "Choose a keyboard shortcut to trigger text correction.\nSelect any text and press this hotkey to correct it.")
        desc.frame = NSRect(x: pad, y: y0, width: W - pad * 2, height: 40)
        desc.font = .systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        view.addSubview(desc)

        // Current hotkey display
        hotkeyDisplayLabel = NSTextField(labelWithString: config.hotkey.displayName)
        hotkeyDisplayLabel.font = .monospacedSystemFont(ofSize: 32, weight: .medium)
        hotkeyDisplayLabel.alignment = .center
        hotkeyDisplayLabel.frame = NSRect(x: pad, y: y0 - 70, width: W - pad * 2, height: 44)
        view.addSubview(hotkeyDisplayLabel)

        // Preset buttons
        let presets: [(label: String, keyCode: UInt16, modifiers: UInt64, display: String)] = [
            ("⌘⇧E", 14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
            ("⌘⇧C", 8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
            ("⌘⇧D", 2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
            ("⌃⇧E", 14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
        ]

        let btnW: CGFloat = 70
        let gap: CGFloat = 10
        let totalW = CGFloat(presets.count) * btnW + CGFloat(presets.count - 1) * gap
        var bx = (W - totalW) / 2

        for (i, preset) in presets.enumerated() {
            let btn = NSButton(title: preset.label, target: self, action: #selector(hotkeyPresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.tag = i
            btn.frame = NSRect(x: bx, y: y0 - 120, width: btnW, height: 28)
            view.addSubview(btn)
            bx += btnW + gap
        }

        // Capture custom button
        let captureBtn = NSButton(title: "Record Custom Hotkey…", target: self, action: #selector(captureCustomHotkey))
        captureBtn.bezelStyle = .rounded
        captureBtn.frame = NSRect(x: (W - 200) / 2, y: y0 - 160, width: 200, height: 28)
        view.addSubview(captureBtn)

        // Reset button
        let resetBtn = NSButton(title: "Reset to Default (⌘⇧E)", target: self, action: #selector(resetHotkey))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: (W - 200) / 2, y: y0 - 200, width: 200, height: 28)
        view.addSubview(resetBtn)

        item.view = view
        return item
    }

    // Preset data (must match button tags)
    private let hotkeyPresets: [(keyCode: UInt16, modifiers: UInt64, display: String)] = [
        (14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
        (8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
        (2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
        (14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
    ]

    @objc private func hotkeyPresetTapped(_ sender: NSButton) {
        let preset = hotkeyPresets[sender.tag]
        config.hotkey = Config.HotkeyConfig(keyCode: preset.keyCode, modifiers: preset.modifiers, displayName: preset.display)
        hotkeyDisplayLabel.stringValue = preset.display
    }

    @objc private func captureCustomHotkey() {
        if let captured = CorrectMeApp.captureHotkey() {
            config.hotkey = Config.HotkeyConfig(
                keyCode: captured.keyCode,
                modifiers: captured.modifiers,
                displayName: captured.displayName
            )
            hotkeyDisplayLabel.stringValue = captured.displayName
        }
    }

    @objc private func resetHotkey() {
        config.hotkey = .default
        hotkeyDisplayLabel.stringValue = Config.HotkeyConfig.default.displayName
    }

    // MARK: - Writing Style Tab

    private let stylePresets: [(label: String, value: String)] = [
        ("More formal",       "Write in a formal, professional tone."),
        ("More casual",       "Write in a casual, friendly tone."),
        ("More concise",      "Make it shorter and more concise."),
        ("More polite",       "Use polite and respectful language."),
        ("Simpler language",  "Use simple, easy-to-understand words."),
        ("Funnier",           "Add a light, humorous touch."),
    ]

    private func makeWritingStyleTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "style")
        item.label = "Writing Style"
        let view = NSView()

        let y0: CGFloat = 340

        // ── Global Style ──
        let globalLabel = NSTextField(labelWithString: "Global Style")
        globalLabel.frame = NSRect(x: pad, y: y0, width: 120, height: 18)
        globalLabel.font = .systemFont(ofSize: 13, weight: .medium)
        view.addSubview(globalLabel)

        let desc = NSTextField(wrappingLabelWithString:
            "Applied to every correction unless overridden by a per-app style:")
        desc.frame = NSRect(x: pad, y: y0 - 22, width: W - pad * 2, height: 20)
        desc.font = .systemFont(ofSize: 11)
        desc.textColor = .secondaryLabelColor
        view.addSubview(desc)

        // Scrollable text view
        let scrollH: CGFloat = 80
        let scrollY: CGFloat = y0 - scrollH - 28
        let scrollView = NSScrollView(frame: NSRect(x: pad, y: scrollY, width: W - pad * 2, height: scrollH))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize), textContainer: textContainer)
        tv.isEditable = true
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 13)
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 6)
        scrollView.documentView = tv
        view.addSubview(scrollView)
        styleTextView = tv

        // Placeholder
        stylePlaceholder = NSTextField(labelWithString: "e.g. \"Write in a formal tone. Use bullet points when listing.\"")
        stylePlaceholder.frame = NSRect(x: pad + 8, y: scrollY + scrollH - 26, width: W - pad * 2 - 16, height: 20)
        stylePlaceholder.font = .systemFont(ofSize: 13)
        stylePlaceholder.textColor = .placeholderTextColor
        stylePlaceholder.isEditable = false
        stylePlaceholder.isBezeled = false
        stylePlaceholder.drawsBackground = false
        view.addSubview(stylePlaceholder)

        // Load saved value
        let saved = config.writingStyle ?? ""
        tv.string = saved
        stylePlaceholder.isHidden = !saved.isEmpty

        // Preset buttons (2 rows of 3)
        let presetY = scrollY - 30
        var bx: CGFloat = pad
        let bh: CGFloat = 22
        let gapX: CGFloat = 6

        for (i, preset) in stylePresets.enumerated() {
            if i == 3 { bx = pad } // second row
            let btn = NSButton(title: preset.label, target: self, action: #selector(stylePresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.font = .systemFont(ofSize: 11)
            btn.tag = i
            let bw = preset.label.size(withAttributes: [.font: btn.font!]).width + 24
            let row: CGFloat = i < 3 ? 1 : 0
            btn.frame = NSRect(x: bx, y: presetY + row * (bh + gapX), width: bw, height: bh)
            view.addSubview(btn)
            bx += bw + gapX
        }

        // Clear style button
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearStyle))
        clearBtn.bezelStyle = .rounded
        clearBtn.frame = NSRect(x: W - pad - 60, y: presetY - 30, width: 60, height: 22)
        view.addSubview(clearBtn)

        // ── Per-App Styles ──
        let perAppY = presetY - 64

        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: perAppY + 20, width: W - pad * 2, height: 1)
        view.addSubview(sep)

        let perAppLabel = NSTextField(labelWithString: "Per-App Styles")
        perAppLabel.frame = NSRect(x: pad, y: perAppY - 4, width: 120, height: 18)
        perAppLabel.font = .systemFont(ofSize: 13, weight: .medium)
        view.addSubview(perAppLabel)

        let perAppDesc = NSTextField(wrappingLabelWithString: "Override the global style for specific apps:")
        perAppDesc.frame = NSRect(x: pad + 120, y: perAppY - 4, width: W - pad * 2 - 120, height: 18)
        perAppDesc.font = .systemFont(ofSize: 11)
        perAppDesc.textColor = .secondaryLabelColor
        view.addSubview(perAppDesc)

        // Container for per-app entries (scrollable)
        let containerH: CGFloat = 80
        let containerY: CGFloat = perAppY - containerH - 10
        let containerScroll = NSScrollView(frame: NSRect(x: pad, y: containerY, width: W - pad * 2, height: containerH))
        containerScroll.hasVerticalScroller = true
        containerScroll.borderType = .bezelBorder
        containerScroll.drawsBackground = true

        let clipView = containerScroll.contentView
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: containerScroll.contentSize.width, height: containerH))
        containerScroll.documentView = containerView
        _ = clipView // suppress unused warning
        view.addSubview(containerScroll)
        perAppStylesContainer = containerView

        // Load per-app entries
        perAppEntries = (config.perAppStyles ?? [:]).map { (bundleId: $0.key, style: $0.value) }
            .sorted { $0.bundleId < $1.bundleId }
        rebuildPerAppList()

        // Add / Remove buttons
        let addBtn = NSButton(title: "Add App…", target: self, action: #selector(addPerAppStyle))
        addBtn.bezelStyle = .rounded
        addBtn.font = .systemFont(ofSize: 11)
        addBtn.frame = NSRect(x: pad, y: containerY - 28, width: 90, height: 22)
        view.addSubview(addBtn)

        let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removePerAppStyle))
        removeBtn.bezelStyle = .rounded
        removeBtn.font = .systemFont(ofSize: 11)
        removeBtn.frame = NSRect(x: pad + 96, y: containerY - 28, width: 70, height: 22)
        view.addSubview(removeBtn)

        item.view = view
        return item
    }

    // MARK: - Per-App Styles Helpers

    private func rebuildPerAppList() {
        guard let container = perAppStylesContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let rowH: CGFloat = 24
        let totalH = max(CGFloat(perAppEntries.count) * rowH, container.superview?.frame.height ?? 80)
        container.frame = NSRect(x: 0, y: 0, width: container.frame.width, height: totalH)

        for (i, entry) in perAppEntries.enumerated() {
            let y = totalH - CGFloat(i + 1) * rowH

            let appLabel = NSTextField(labelWithString: entry.bundleId)
            appLabel.frame = NSRect(x: 4, y: y, width: 180, height: rowH)
            appLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            appLabel.lineBreakMode = .byTruncatingMiddle
            container.addSubview(appLabel)

            let styleLabel = NSTextField(labelWithString: entry.style)
            styleLabel.frame = NSRect(x: 188, y: y, width: container.frame.width - 192, height: rowH)
            styleLabel.font = .systemFont(ofSize: 11)
            styleLabel.textColor = .secondaryLabelColor
            styleLabel.lineBreakMode = .byTruncatingTail
            container.addSubview(styleLabel)
        }

        if perAppEntries.isEmpty {
            let placeholder = NSTextField(labelWithString: "No per-app styles configured")
            placeholder.frame = NSRect(x: 4, y: (totalH - 20) / 2, width: container.frame.width - 8, height: 20)
            placeholder.font = .systemFont(ofSize: 11)
            placeholder.textColor = .tertiaryLabelColor
            placeholder.alignment = .center
            container.addSubview(placeholder)
        }
    }

    @objc private func addPerAppStyle() {
        let alert = NSAlert()
        alert.messageText = "Add Per-App Style"
        alert.informativeText = "Select a running app or enter a bundle ID, then set the writing style for that app."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 100))

        // App picker (running apps)
        let appPopUp = NSPopUpButton(frame: NSRect(x: 0, y: 72, width: 340, height: 26), pullsDown: false)
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        appPopUp.addItem(withTitle: "Choose from running apps…")
        for app in runningApps {
            let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            let bundleId = app.bundleIdentifier ?? ""
            appPopUp.addItem(withTitle: "\(name)  (\(bundleId))")
            appPopUp.lastItem?.representedObject = bundleId
        }
        accessory.addSubview(appPopUp)

        // Style field
        let styleField = NSTextField(frame: NSRect(x: 0, y: 6, width: 340, height: 60))
        styleField.placeholderString = "Writing style for this app (e.g. \"casual tone\")"
        styleField.font = .systemFont(ofSize: 12)
        accessory.addSubview(styleField)

        alert.accessoryView = accessory

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let bundleId: String
        if appPopUp.indexOfSelectedItem > 0,
           let selected = appPopUp.selectedItem?.representedObject as? String {
            bundleId = selected
        } else {
            return
        }

        let style = styleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !style.isEmpty else { return }

        // Replace existing or add new
        if let idx = perAppEntries.firstIndex(where: { $0.bundleId == bundleId }) {
            perAppEntries[idx].style = style
        } else {
            perAppEntries.append((bundleId: bundleId, style: style))
        }

        rebuildPerAppList()
    }

    @objc private func removePerAppStyle() {
        guard !perAppEntries.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Remove Per-App Style"
        alert.informativeText = "Select an app to remove its custom style:"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26), pullsDown: false)
        for entry in perAppEntries {
            popUp.addItem(withTitle: entry.bundleId)
        }
        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let idx = popUp.indexOfSelectedItem
        guard idx >= 0, idx < perAppEntries.count else { return }
        perAppEntries.remove(at: idx)
        rebuildPerAppList()
    }

    @objc private func stylePresetTapped(_ sender: NSButton) {
        let preset = stylePresets[sender.tag]
        let current = styleTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            styleTextView.string = preset.value
        } else if !current.hasSuffix(preset.value) {
            styleTextView.string = current + " " + preset.value
        }
        stylePlaceholder.isHidden = !styleTextView.string.isEmpty
    }

    @objc private func clearStyle() {
        styleTextView.string = ""
        stylePlaceholder.isHidden = false
    }

    // MARK: - Advanced Tab

    private func makeAdvancedTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "advanced")
        item.label = "Advanced"
        let view = NSView()

        let y0: CGFloat = 280

        // Config file path
        let pathLabel = NSTextField(labelWithString: "Config file:")
        pathLabel.frame = NSRect(x: pad, y: y0, width: 80, height: 20)
        pathLabel.font = .systemFont(ofSize: 13)
        view.addSubview(pathLabel)

        let pathValue = NSTextField(labelWithString: Config.configPath.path)
        pathValue.frame = NSRect(x: 100, y: y0, width: W - 100 - pad, height: 20)
        pathValue.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathValue.textColor = .secondaryLabelColor
        pathValue.lineBreakMode = .byTruncatingMiddle
        view.addSubview(pathValue)

        // Open in Finder
        let openBtn = NSButton(title: "Show in Finder", target: self, action: #selector(showConfigInFinder))
        openBtn.bezelStyle = .rounded
        openBtn.frame = NSRect(x: pad, y: y0 - 35, width: 140, height: 28)
        view.addSubview(openBtn)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: y0 - 65, width: W - pad * 2, height: 1)
        view.addSubview(sep)

        // Export / Import
        let exportBtn = NSButton(title: "Export Config…", target: self, action: #selector(exportConfig))
        exportBtn.bezelStyle = .rounded
        exportBtn.frame = NSRect(x: pad, y: y0 - 100, width: 140, height: 28)
        view.addSubview(exportBtn)

        let importBtn = NSButton(title: "Import Config…", target: self, action: #selector(importConfig))
        importBtn.bezelStyle = .rounded
        importBtn.frame = NSRect(x: pad + 150, y: y0 - 100, width: 140, height: 28)
        view.addSubview(importBtn)

        // Separator
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.frame = NSRect(x: pad, y: y0 - 130, width: W - pad * 2, height: 1)
        view.addSubview(sep2)

        // Danger zone
        let dangerLabel = NSTextField(labelWithString: "Reset")
        dangerLabel.frame = NSRect(x: pad, y: y0 - 160, width: 100, height: 20)
        dangerLabel.font = .systemFont(ofSize: 13, weight: .medium)
        view.addSubview(dangerLabel)

        let resetBtn = NSButton(title: "Reset All Settings", target: self, action: #selector(resetAllSettings))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: pad, y: y0 - 195, width: 160, height: 28)
        view.addSubview(resetBtn)

        item.view = view
        return item
    }

    @objc private func showConfigInFinder() {
        let dir = Config.configPath.deletingLastPathComponent()
        NSWorkspace.shared.selectFile(Config.configPath.path, inFileViewerRootedAtPath: dir.path)
    }

    @objc private func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "config.json"
        panel.allowedContentTypes = [.json]
        panel.level = .floating

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: Config.configPath)
            try data.write(to: url)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    @objc private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.level = .floating

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            // Validate it's valid config
            _ = try JSONDecoder().decode(Config.self, from: data)
            try data.write(to: Config.configPath)

            // Reload
            config = Config.load()
            window?.close()
            window = nil
            showWindow()
        } catch {
            showAlert(title: "Import Failed", message: "Invalid config file: \(error.localizedDescription)")
        }
    }

    @objc private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all settings to defaults. Your API keys will be removed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        config = .default
        try? config.save()
        window?.close()
        window = nil
        showWindow()
    }

    // MARK: - Save / Cancel

    @objc private func save() {
        // Collect from Provider tab
        config.aiProvider = selectedProvider()

        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerNeedsAPIKey(config.aiProvider) && !key.isEmpty {
            switch config.aiProvider {
            case .claude: config.anthropicAPIKey = key
            case .gemini: config.geminiAPIKey = key
            case .codex: config.openaiAPIKey = key
            default: break
            }
        }

        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.model = model.isEmpty ? nil : model

        // Collect from Writing Style tab
        let style = styleTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        config.writingStyle = style.isEmpty ? nil : style

        // Collect per-app styles
        if perAppEntries.isEmpty {
            config.perAppStyles = nil
        } else {
            var dict: [String: String] = [:]
            for entry in perAppEntries {
                dict[entry.bundleId] = entry.style
            }
            config.perAppStyles = dict
        }

        // Save
        do {
            try config.save()
        } catch {
            showAlert(title: "Save Failed", message: error.localizedDescription)
            return
        }

        // Notify that config changed (so HotkeyManager can reload)
        NotificationCenter.default.post(name: .configChanged, object: nil)

        window?.close()
    }

    @objc private func cancel() {
        window?.close()
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - Notification name for config changes

extension Notification.Name {
    static let configChanged = Notification.Name("com.correctme.configChanged")
}
