import AppKit
import CoreGraphics

/// Full Preferences window with tabs: General, Provider, Hotkey, Writing Style, Advanced.
/// Styled to match macOS Sequoia system settings.
class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSPanel?
    private var tabView: NSTabView!
    private var segmentedControl: NSSegmentedControl!

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
    private var forceApplyCheckbox: NSButton!

    private let W: CGFloat = 560
    private let H: CGFloat = 560
    private let pad: CGFloat = 24

    private override init() { super.init() }

    // MARK: - Helpers

    private func makeSFSymbol(_ name: String, size: CGFloat, color: NSColor? = nil) -> NSImageView {
        let imageView = NSImageView()
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                imageView.image = image
                if let color = color {
                    imageView.contentTintColor = color
                }
            }
        }
        return imageView
    }

    private func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSeparator(x: CGFloat, y: CGFloat, width: CGFloat) -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: x, y: y, width: width, height: 1)
        return sep
    }

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
        panel.titlebarAppearsTransparent = false
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.backgroundColor = .windowBackgroundColor

        let root = NSView(frame: panel.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        panel.contentView = root

        // Segmented control for tab switching
        let tabLabels = ["General", "Provider", "Hotkey", "Writing Style", "Advanced"]
        segmentedControl = NSSegmentedControl(labels: tabLabels, trackingMode: .selectOne, target: self, action: #selector(segmentChanged(_:)))
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentStyle = .automatic
        segmentedControl.controlSize = .regular
        segmentedControl.sizeToFit()
        let segW = segmentedControl.fittingSize.width
        let segH: CGFloat = 24
        segmentedControl.frame = NSRect(x: (W - segW) / 2, y: H - 44, width: segW, height: segH)
        segmentedControl.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        root.addSubview(segmentedControl)

        // Separator below segmented control
        let tabSep = NSBox()
        tabSep.boxType = .separator
        tabSep.frame = NSRect(x: 0, y: H - 56, width: W, height: 1)
        tabSep.autoresizingMask = [.width, .minYMargin]
        root.addSubview(tabSep)

        // Tab view (hidden tabs — content only)
        tabView = NSTabView(frame: NSRect(x: 0, y: 50, width: W, height: H - 106))
        tabView.autoresizingMask = [.width, .height]
        tabView.tabViewType = .noTabsNoBorder
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
        saveBtn.controlSize = .large
        saveBtn.frame = NSRect(x: W - pad - 90, y: 12, width: 90, height: 32)
        saveBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        root.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.controlSize = .large
        cancelBtn.frame = NSRect(x: W - pad - 190, y: 12, width: 90, height: 32)
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

        let contentW = W - pad * 2
        var y: CGFloat = 320

        // Section: Behavior
        let behaviorLabel = makeSectionHeader("Behavior")
        behaviorLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(behaviorLabel)
        y -= 30

        autoStartCheckbox = NSButton(checkboxWithTitle: "Start CorrectMe at login", target: nil, action: nil)
        autoStartCheckbox.frame = NSRect(x: pad, y: y, width: contentW, height: 20)
        autoStartCheckbox.state = DaemonManager.isLaunchAgentInstalled ? .on : .off
        view.addSubview(autoStartCheckbox)
        y -= 26

        forceApplyCheckbox = NSButton(checkboxWithTitle: "Apply corrections immediately (skip review)", target: nil, action: nil)
        forceApplyCheckbox.frame = NSRect(x: pad, y: y, width: contentW, height: 20)
        forceApplyCheckbox.state = (config.forceApply ?? false) ? .on : .off
        view.addSubview(forceApplyCheckbox)
        y -= 36

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 24

        // Section: Current Configuration
        let configLabel = makeSectionHeader("Current Configuration")
        configLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(configLabel)
        y -= 28

        let hotkeyRow = makeInfoRow(label: "Hotkey:", value: config.hotkey.displayName, isMono: true)
        hotkeyRow.frame = NSRect(x: pad, y: y, width: contentW, height: 20)
        view.addSubview(hotkeyRow)
        y -= 24

        let providerRow = makeInfoRow(label: "Provider:", value: config.aiProvider.rawValue, isMono: false)
        providerRow.frame = NSRect(x: pad, y: y, width: contentW, height: 20)
        view.addSubview(providerRow)
        y -= 24

        let modelRow = makeInfoRow(label: "Model:", value: config.model ?? "(default)", isMono: false)
        modelRow.frame = NSRect(x: pad, y: y, width: contentW, height: 20)
        view.addSubview(modelRow)
        y -= 36

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 24

        // Version
        let versionLabel = NSTextField(labelWithString: "CorrectMe \(AppVersion.fullVersion)")
        versionLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 16)
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .tertiaryLabelColor
        view.addSubview(versionLabel)

        item.view = view
        return item
    }

    private func makeInfoRow(label: String, value: String, isMono: Bool) -> NSView {
        let row = NSView()

        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)
        labelField.textColor = .secondaryLabelColor
        labelField.frame = NSRect(x: 0, y: 0, width: 80, height: 20)
        row.addSubview(labelField)

        let valueField = NSTextField(labelWithString: value)
        valueField.font = isMono ? .monospacedSystemFont(ofSize: 13, weight: .medium) : .systemFont(ofSize: 13)
        valueField.textColor = .labelColor
        valueField.frame = NSRect(x: 84, y: 0, width: 300, height: 20)
        row.addSubview(valueField)

        return row
    }

    // MARK: - Provider Tab

    private func makeProviderTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "provider")
        item.label = "Provider"
        let view = NSView()

        let contentW = W - pad * 2
        var y: CGFloat = 320

        // Provider dropdown
        let pLabel = makeSectionHeader("AI Provider")
        pLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(pLabel)
        y -= 28

        providerPopUp = NSPopUpButton(frame: NSRect(x: pad, y: y, width: contentW, height: 26), pullsDown: false)
        providerPopUp.controlSize = .large
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
        for i in 0..<providers.count {
            if providers[i].value == config.aiProvider {
                providerPopUp.selectItem(at: i)
                break
            }
        }
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged)
        view.addSubview(providerPopUp)
        y -= 36

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 20

        // API Key
        apiKeyLabel = makeSectionHeader("API Key")
        apiKeyLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(apiKeyLabel)
        y -= 28

        apiKeyField = NSSecureTextField(frame: NSRect(x: pad, y: y, width: contentW, height: 24))
        apiKeyField.placeholderString = "sk-ant-... / AIzaSy... / sk-..."
        apiKeyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        apiKeyField.controlSize = .large
        view.addSubview(apiKeyField)
        loadAPIKeyForCurrentProvider()
        y -= 34

        // Test button
        testButton = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testButton.bezelStyle = .rounded
        testButton.frame = NSRect(x: pad, y: y, width: 140, height: 28)
        view.addSubview(testButton)

        testResultLabel = NSTextField(labelWithString: "")
        testResultLabel.frame = NSRect(x: pad + 148, y: y, width: contentW - 148, height: 28)
        testResultLabel.font = .systemFont(ofSize: 12)
        view.addSubview(testResultLabel)
        y -= 36

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 20

        // Model
        let mLabel = makeSectionHeader("Model")
        mLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(mLabel)
        y -= 28

        modelField = NSTextField(frame: NSRect(x: pad, y: y, width: contentW, height: 24))
        modelField.placeholderString = defaultModelForProvider(config.aiProvider)
        modelField.stringValue = config.model ?? ""
        modelField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        modelField.controlSize = .large
        view.addSubview(modelField)
        y -= 28

        // Hint
        apiKeyHint = NSTextField(wrappingLabelWithString: "")
        apiKeyHint.frame = NSRect(x: pad, y: y, width: contentW, height: 32)
        apiKeyHint.font = .systemFont(ofSize: 11)
        apiKeyHint.textColor = .tertiaryLabelColor
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
                    self?.testResultLabel.stringValue = "✓ Connection successful!"
                    self?.testResultLabel.textColor = .systemGreen
                } else {
                    self?.testResultLabel.stringValue = "✕ Connection failed. Check your key."
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

        let contentW = W - pad * 2
        var y: CGFloat = 320

        let desc = makeDescriptionLabel("Choose a keyboard shortcut to trigger text correction.\nSelect any text and press this hotkey to correct it.")
        desc.frame = NSRect(x: pad, y: y, width: contentW, height: 36)
        view.addSubview(desc)
        y -= 50

        // Current hotkey display — keycap style
        let keyCapBg = NSView()
        keyCapBg.wantsLayer = true
        keyCapBg.layer?.cornerRadius = 12
        keyCapBg.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keyCapBg.layer?.borderWidth = 1
        keyCapBg.layer?.borderColor = NSColor.separatorColor.cgColor
        let keyCapWidth: CGFloat = 200
        keyCapBg.frame = NSRect(x: (W - keyCapWidth) / 2, y: y, width: keyCapWidth, height: 52)
        view.addSubview(keyCapBg)

        hotkeyDisplayLabel = NSTextField(labelWithString: config.hotkey.displayName)
        hotkeyDisplayLabel.font = .monospacedSystemFont(ofSize: 32, weight: .medium)
        hotkeyDisplayLabel.alignment = .center
        hotkeyDisplayLabel.textColor = .labelColor
        hotkeyDisplayLabel.frame = NSRect(x: 0, y: 6, width: keyCapWidth, height: 40)
        keyCapBg.addSubview(hotkeyDisplayLabel)
        y -= 72

        // Preset buttons
        let presets: [(label: String, keyCode: UInt16, modifiers: UInt64, display: String)] = [
            ("⌘⇧E", 14, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧E"),
            ("⌘⇧C", 8, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧C"),
            ("⌘⇧D", 2, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, "⌘⇧D"),
            ("⌃⇧E", 14, CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue, "⌃⇧E"),
        ]

        let btnW: CGFloat = 66
        let gap: CGFloat = 10
        let totalW = CGFloat(presets.count) * btnW + CGFloat(presets.count - 1) * gap
        var bx = (W - totalW) / 2

        for (i, preset) in presets.enumerated() {
            let btn = NSButton(title: preset.label, target: self, action: #selector(hotkeyPresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.tag = i
            btn.frame = NSRect(x: bx, y: y, width: btnW, height: 28)
            view.addSubview(btn)
            bx += btnW + gap
        }
        y -= 40

        // Capture custom button
        let captureBtn = NSButton(title: "Record Custom Hotkey…", target: self, action: #selector(captureCustomHotkey))
        captureBtn.bezelStyle = .rounded
        captureBtn.frame = NSRect(x: (W - 200) / 2, y: y, width: 200, height: 28)
        view.addSubview(captureBtn)
        y -= 40

        // Reset button
        let resetBtn = NSButton(title: "Reset to Default (⌘⇧E)", target: self, action: #selector(resetHotkey))
        resetBtn.bezelStyle = .accessoryBarAction
        resetBtn.frame = NSRect(x: (W - 200) / 2, y: y, width: 200, height: 24)
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

        let contentW = W - pad * 2
        var y: CGFloat = 340

        // ── Global Style ──
        let globalLabel = makeSectionHeader("Global Style")
        globalLabel.frame = NSRect(x: pad, y: y, width: 120, height: 18)
        view.addSubview(globalLabel)
        y -= 20

        let desc = makeDescriptionLabel("Applied to every correction unless overridden by a per-app style:")
        desc.frame = NSRect(x: pad, y: y, width: contentW, height: 16)
        view.addSubview(desc)
        y -= 24

        // Scrollable text view
        let scrollH: CGFloat = 80
        let scrollView = NSScrollView(frame: NSRect(x: pad, y: y - scrollH, width: contentW, height: scrollH))
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
        stylePlaceholder.frame = NSRect(x: pad + 8, y: y - 26, width: contentW - 16, height: 20)
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

        y -= scrollH + 8

        // Preset buttons (2 rows of 3)
        let bh: CGFloat = 22
        let gapX: CGFloat = 6
        var bx: CGFloat = pad

        for (i, preset) in stylePresets.enumerated() {
            if i == 3 { bx = pad }
            let btn = NSButton(title: preset.label, target: self, action: #selector(stylePresetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.font = .systemFont(ofSize: 11)
            btn.tag = i
            let bw = preset.label.size(withAttributes: [.font: btn.font!]).width + 24
            let row: CGFloat = i < 3 ? 1 : 0
            btn.frame = NSRect(x: bx, y: y - bh * 2 - gapX + row * (bh + gapX), width: bw, height: bh)
            view.addSubview(btn)
            bx += bw + gapX
        }

        // Clear style button
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearStyle))
        clearBtn.bezelStyle = .accessoryBarAction
        clearBtn.frame = NSRect(x: W - pad - 50, y: y - bh * 2 - gapX - 6, width: 50, height: 20)
        view.addSubview(clearBtn)

        y -= bh * 2 + gapX + 16

        // ── Per-App Styles ──
        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 20

        let perAppLabel = makeSectionHeader("Per-App Styles")
        perAppLabel.frame = NSRect(x: pad, y: y, width: 120, height: 18)
        view.addSubview(perAppLabel)

        let perAppDesc = makeDescriptionLabel("Override the global style for specific apps:")
        perAppDesc.frame = NSRect(x: pad + 124, y: y, width: contentW - 124, height: 18)
        view.addSubview(perAppDesc)
        y -= 24

        // Container for per-app entries (scrollable)
        let containerH: CGFloat = 80
        let containerScroll = NSScrollView(frame: NSRect(x: pad, y: y - containerH, width: contentW, height: containerH))
        containerScroll.hasVerticalScroller = true
        containerScroll.borderType = .bezelBorder
        containerScroll.drawsBackground = true

        let clipView = containerScroll.contentView
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: containerScroll.contentSize.width, height: containerH))
        containerScroll.documentView = containerView
        _ = clipView
        view.addSubview(containerScroll)
        perAppStylesContainer = containerView

        // Load per-app entries
        perAppEntries = (config.perAppStyles ?? [:]).map { (bundleId: $0.key, style: $0.value) }
            .sorted { $0.bundleId < $1.bundleId }
        rebuildPerAppList()

        y -= containerH + 6

        // Add / Remove buttons
        let addBtn = NSButton(title: "Add App…", target: self, action: #selector(addPerAppStyle))
        addBtn.bezelStyle = .rounded
        addBtn.font = .systemFont(ofSize: 11)
        addBtn.frame = NSRect(x: pad, y: y, width: 90, height: 22)
        view.addSubview(addBtn)

        let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removePerAppStyle))
        removeBtn.bezelStyle = .rounded
        removeBtn.font = .systemFont(ofSize: 11)
        removeBtn.frame = NSRect(x: pad + 96, y: y, width: 70, height: 22)
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

        let contentW = W - pad * 2
        var y: CGFloat = 320

        // Config file path
        let pathHeader = makeSectionHeader("Configuration File")
        pathHeader.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(pathHeader)
        y -= 24

        let pathValue = NSTextField(labelWithString: Config.configPath.path)
        pathValue.frame = NSRect(x: pad, y: y, width: contentW, height: 16)
        pathValue.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathValue.textColor = .secondaryLabelColor
        pathValue.lineBreakMode = .byTruncatingMiddle
        view.addSubview(pathValue)
        y -= 28

        let openBtn = NSButton(title: "Show in Finder", target: self, action: #selector(showConfigInFinder))
        openBtn.bezelStyle = .rounded
        openBtn.frame = NSRect(x: pad, y: y, width: 140, height: 28)
        view.addSubview(openBtn)
        y -= 40

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 24

        // Export / Import
        let transferHeader = makeSectionHeader("Transfer")
        transferHeader.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(transferHeader)
        y -= 28

        let exportBtn = NSButton(title: "Export Config…", target: self, action: #selector(exportConfig))
        exportBtn.bezelStyle = .rounded
        exportBtn.frame = NSRect(x: pad, y: y, width: 140, height: 28)
        view.addSubview(exportBtn)

        let importBtn = NSButton(title: "Import Config…", target: self, action: #selector(importConfig))
        importBtn.bezelStyle = .rounded
        importBtn.frame = NSRect(x: pad + 150, y: y, width: 140, height: 28)
        view.addSubview(importBtn)
        y -= 44

        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 24

        // Danger zone
        let dangerHeader = makeSectionHeader("Reset")
        dangerHeader.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        dangerHeader.textColor = .systemRed
        view.addSubview(dangerHeader)
        y -= 28

        let resetBtn = NSButton(title: "Reset All Settings", target: self, action: #selector(resetAllSettings))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: pad, y: y, width: 160, height: 28)
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
            _ = try JSONDecoder().decode(Config.self, from: data)
            try data.write(to: Config.configPath)

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

    // MARK: - Tab Switching

    @objc private func segmentChanged(_ sender: NSSegmentedControl) {
        tabView.selectTabViewItem(at: sender.selectedSegment)
    }

    // MARK: - Save / Cancel

    @objc private func save() {
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

        let style = styleTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        config.writingStyle = style.isEmpty ? nil : style

        if perAppEntries.isEmpty {
            config.perAppStyles = nil
        } else {
            var dict: [String: String] = [:]
            for entry in perAppEntries {
                dict[entry.bundleId] = entry.style
            }
            config.perAppStyles = dict
        }

        config.forceApply = forceApplyCheckbox.state == .on ? true : nil

        do {
            try config.save()
        } catch {
            showAlert(title: "Save Failed", message: error.localizedDescription)
            return
        }

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
