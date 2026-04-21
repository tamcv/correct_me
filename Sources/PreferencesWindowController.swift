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
    private var apiKeyToggleBtn: NSButton!
    private var apiKeyPreviewLabel: NSTextField!
    private var modelField: NSTextField!
    private var fallbackModelsField: NSTextField!
    private var findModelsButton: NSButton!
    private var findModelsStatus: NSTextField!
    private var testResultLabel: NSTextField!
    private var testButton: NSButton!
    private var apiKeyLabel: NSTextField!
    private var apiKeyHint: NSTextField!

    // Hotkey tab
    private var hotkeyDisplayLabel: NSTextField!

    // Writing Style tab
    private var styleTextView: NSTextView!

    // Per-app styles
    private var perAppStylesContainer: NSView!
    private var perAppEntries: [(bundleId: String, style: String)] = []

    // Add-app panel references
    private var addAppPanel: NSPanel?
    private var addAppPopUpRef: NSPopUpButton?
    private var addAppStyleViewRef: NSTextView?

    // Edit-app panel references
    private var editAppPanel: NSPanel?
    private var editAppStyleViewRef: NSTextView?
    private var editingIndex: Int = -1

    // General tab
    private var autoStartCheckbox: NSButton!
    private var forceApplyCheckbox: NSButton!

    private let W: CGFloat = 560
    private let H: CGFloat = 560
    private let pad: CGFloat = 24

    private let defaultWritingStyle = "Fix grammar and spelling only. Keep original tone."

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
        var y: CGFloat = 430

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
            ("OpenRouter API", .openrouter),
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

        // API key input (secure field — single line of dots)
        let fieldW = contentW - 148  // room for Show + Paste buttons
        apiKeyField = NSSecureTextField(frame: NSRect(x: pad, y: y, width: fieldW, height: 24))
        apiKeyField.placeholderString = "Paste your API key here"
        apiKeyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        apiKeyField.controlSize = .large
        apiKeyField.target = self
        apiKeyField.action = #selector(apiKeyFieldChanged)
        view.addSubview(apiKeyField)

        // Show button — reveals full key in a popover
        apiKeyToggleBtn = NSButton(title: "👁 Show", target: self, action: #selector(toggleAPIKeyVisibility))
        apiKeyToggleBtn.bezelStyle = .rounded
        apiKeyToggleBtn.controlSize = .small
        apiKeyToggleBtn.frame = NSRect(x: pad + fieldW + 6, y: y, width: 68, height: 24)
        view.addSubview(apiKeyToggleBtn)

        // Paste button
        let pasteBtn = NSButton(title: "Paste", target: self, action: #selector(pasteAPIKey))
        pasteBtn.bezelStyle = .rounded
        pasteBtn.controlSize = .small
        pasteBtn.frame = NSRect(x: pad + fieldW + 78, y: y, width: 68, height: 24)
        view.addSubview(pasteBtn)

        loadAPIKeyForCurrentProvider()
        y -= 28  // field height (24) + 4px gap

        // One-line masked preview: "sk-or-v1…91b1  (73 chars)"
        apiKeyPreviewLabel = NSTextField(labelWithString: "")
        apiKeyPreviewLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 16)
        apiKeyPreviewLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        apiKeyPreviewLabel.textColor = .tertiaryLabelColor
        view.addSubview(apiKeyPreviewLabel)
        updateAPIKeyPreview()
        y -= 24

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

        // Model (primary)
        let mLabel = makeSectionHeader("Primary Model")
        mLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        view.addSubview(mLabel)
        y -= 28

        modelField = NSTextField(frame: NSRect(x: pad, y: y, width: contentW, height: 24))
        modelField.placeholderString = defaultModelForProvider(config.aiProvider)
        modelField.stringValue = config.model ?? ""
        modelField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        modelField.controlSize = .large
        view.addSubview(modelField)
        y -= 30

        // Fallback models (OpenRouter-specific, shown/hidden via updateProviderUI)
        let fbLabel = makeSectionHeader("Fallback Models (retry on 429)")
        fbLabel.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        fbLabel.tag = 700  // tag for show/hide
        view.addSubview(fbLabel)
        y -= 26  // label height (18) + 8px gap

        let fbHint = NSTextField(labelWithString: "One model per line. Tried in order if primary returns 429.")
        fbHint.frame = NSRect(x: pad, y: y, width: contentW, height: 14)
        fbHint.font = .systemFont(ofSize: 10)
        fbHint.textColor = .tertiaryLabelColor
        fbHint.tag = 701
        view.addSubview(fbHint)
        y -= 20

        // Multi-line text field for fallback models (using NSScrollView + NSTextView would be heavy,
        // so use a tall NSTextField with wrapping)
        fallbackModelsField = NSTextField(frame: NSRect(x: pad, y: y - 52, width: contentW - 110, height: 72))
        fallbackModelsField.placeholderString = "e.g.\nmeta-llama/llama-3.1-8b-instruct:free\ngoogle/gemma-3-1b-it:free"
        fallbackModelsField.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        fallbackModelsField.lineBreakMode = .byCharWrapping
        fallbackModelsField.usesSingleLineMode = false
        fallbackModelsField.maximumNumberOfLines = 5
        fallbackModelsField.tag = 702
        // Load existing fallback models
        if let fallbacks = config.fallbackModels, !fallbacks.isEmpty {
            fallbackModelsField.stringValue = fallbacks.joined(separator: "\n")
        }
        view.addSubview(fallbackModelsField)

        // "Find Best Models" button
        findModelsButton = NSButton(title: "Find Best\nFree Models", target: self, action: #selector(findBestFreeModels))
        findModelsButton.bezelStyle = .rounded
        findModelsButton.frame = NSRect(x: pad + contentW - 102, y: y - 52, width: 102, height: 42)
        findModelsButton.tag = 703
        view.addSubview(findModelsButton)

        // Status label for find operation
        findModelsStatus = NSTextField(labelWithString: "")
        findModelsStatus.frame = NSRect(x: pad + contentW - 102, y: y - 14, width: 102, height: 14)
        findModelsStatus.font = .systemFont(ofSize: 9)
        findModelsStatus.textColor = .secondaryLabelColor
        findModelsStatus.alignment = .center
        findModelsStatus.tag = 704
        view.addSubview(findModelsStatus)

        y -= 80

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
        case .claude, .gemini, .codex, .openrouter: return true
        case .claudeCode, .codexCode, .copilot: return false
        }
    }

    private func updateProviderUI() {
        let provider = selectedProvider()
        let needsKey = providerNeedsAPIKey(provider)

        apiKeyField.isEnabled = needsKey
        apiKeyToggleBtn.isEnabled = needsKey
        apiKeyLabel.textColor = needsKey ? .labelColor : .tertiaryLabelColor
        testButton.isEnabled = needsKey

        if needsKey {
            apiKeyHint.stringValue = "Your API key is stored securely in the macOS Keychain."
        } else {
            apiKeyHint.stringValue = "This provider uses a local CLI tool. No API key needed."
            setAPIKeyValue("")
        }

        modelField.placeholderString = defaultModelForProvider(provider)
        testResultLabel.stringValue = ""

        // Show fallback models only for OpenRouter
        let showFallback = provider == .openrouter
        for tag in 700...704 {
            apiKeyField.superview?.viewWithTag(tag)?.isHidden = !showFallback
        }
        fallbackModelsField?.isHidden = !showFallback
        findModelsButton?.isHidden = !showFallback
        findModelsStatus?.isHidden = !showFallback

        loadAPIKeyForCurrentProvider()
        updateAPIKeyPreview()
    }

    private func loadAPIKeyForCurrentProvider() {
        let provider = selectedProvider()
        guard providerNeedsAPIKey(provider) else {
            setAPIKeyValue("")
            return
        }

        let value: String
        switch provider {
        case .claude:     value = config.anthropicAPIKey ?? ""
        case .gemini:     value = config.geminiAPIKey ?? ""
        case .codex:      value = config.openaiAPIKey ?? ""
        case .openrouter: value = config.openrouterAPIKey ?? ""
        default:          value = ""
        }
        setAPIKeyValue(value)
        updateAPIKeyPreview()
    }

    /// Get the current API key value from whichever field is active.
    private func currentAPIKeyValue() -> String {
        return apiKeyField?.stringValue ?? ""
    }

    /// Set the API key value.
    private func setAPIKeyValue(_ value: String) {
        apiKeyField?.stringValue = value
    }

    /// Show a masked preview: "sk-ant-a...xY4z  (51 chars)" so the user
    /// can verify the key was pasted correctly without revealing it entirely.
    private func updateAPIKeyPreview() {
        guard let label = apiKeyPreviewLabel else { return }
        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            label.stringValue = ""
            return
        }
        let count = key.count
        let preview: String
        if count <= 10 {
            preview = String(repeating: "•", count: count)
        } else {
            preview = "\(String(key.prefix(8)))…\(String(key.suffix(4)))"
        }
        label.stringValue = "\(preview)  (\(count) chars)"
    }

    @objc private func toggleAPIKeyVisibility() {
        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        // Show full key in a popover anchored to the Show button
        let popover = NSPopover()
        popover.behavior = .transient  // auto-close on click outside

        let vc = NSViewController()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 100))

        // Readable, selectable, word-wrapping text view for the full key
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 40, width: 396, height: 48))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 390, height: 44))
        textView.string = key
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 6, height: 4)
        textView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView
        container.addSubview(scrollView)

        // Copy button
        let copyBtn = NSButton(title: "Copy to Clipboard", target: nil, action: nil)
        copyBtn.bezelStyle = .rounded
        copyBtn.controlSize = .small
        copyBtn.sizeToFit()
        copyBtn.frame.origin = NSPoint(x: 12, y: 8)
        container.addSubview(copyBtn)

        // Char count
        let countLabel = NSTextField(labelWithString: "\(key.count) characters")
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.sizeToFit()
        countLabel.frame.origin = NSPoint(x: 420 - countLabel.frame.width - 12, y: 12)
        container.addSubview(countLabel)

        vc.view = container
        popover.contentViewController = vc

        // Wire copy button action via target-action on the button
        copyBtn.target = self
        copyBtn.action = #selector(copyKeyFromPopover(_:))
        copyBtn.tag = key.hashValue  // store for identification

        popover.show(relativeTo: apiKeyToggleBtn.bounds, of: apiKeyToggleBtn, preferredEdge: .maxY)
    }

    @objc private func copyKeyFromPopover(_ sender: NSButton) {
        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(key, forType: .string)
        sender.title = "✓ Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sender.title = "Copy to Clipboard"
        }
    }

    @objc private func pasteAPIKey() {
        guard let clip = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        setAPIKeyValue(trimmed)
        updateAPIKeyPreview()
        // Flash the preview green briefly to confirm paste
        apiKeyPreviewLabel.textColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.apiKeyPreviewLabel.textColor = .tertiaryLabelColor
        }
    }

    @objc private func apiKeyFieldChanged() {
        updateAPIKeyPreview()
    }

    @objc private func findBestFreeModels() {
        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            findModelsStatus?.stringValue = "Enter API key first"
            findModelsStatus?.textColor = .systemRed
            return
        }

        findModelsButton?.isEnabled = false
        findModelsStatus?.stringValue = "Fetching models..."
        findModelsStatus?.textColor = .secondaryLabelColor

        Task {
            // 1. Fetch free models (pre-filtered to known-good families, capped at ~10)
            let (totalFree, candidates) = await OpenRouterProvider.fetchFreeModels(apiKey: key)
            guard !candidates.isEmpty else {
                await MainActor.run {
                    let msg = totalFree == 0
                        ? "No free models found"
                        : "No suitable free models found (from \(totalFree) available)"
                    findModelsStatus?.stringValue = msg
                    findModelsStatus?.textColor = .systemRed
                    findModelsButton?.isEnabled = true
                }
                return
            }

            await MainActor.run {
                findModelsStatus?.stringValue = "Testing \(candidates.count) of \(totalFree) free models..."
            }

            // 2. Benchmark candidates sequentially with delay to avoid burning rate limit.
            //    Running in parallel would fire ~20 calls at once → 429 for all subsequent usage.
            var results: [(id: String, latencyMs: Int, quality: Double)] = []
            for (index, model) in candidates.enumerated() {
                await MainActor.run {
                    findModelsStatus?.stringValue = "Testing \(index + 1)/\(candidates.count): \(model.name)..."
                }

                if let result = await OpenRouterProvider.benchmarkModel(apiKey: key, modelId: model.id) {
                    results.append(result)
                }

                // Small delay between models to spread rate limit usage
                if index < candidates.count - 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }

            // 3. Filter out low-quality models (score < 0.5), then sort by quality desc, latency asc
            let qualityThreshold = 0.5
            let goodModels = results.filter { $0.quality >= qualityThreshold }
            // Sort: higher quality first, then lower latency as tiebreaker
            let sorted = goodModels.sorted { a, b in
                if abs(a.quality - b.quality) > 0.1 {
                    return a.quality > b.quality  // better quality wins
                }
                return a.latencyMs < b.latencyMs  // same quality tier → faster wins
            }
            let best = Array(sorted.prefix(5))
            let droppedCount = results.count - goodModels.count

            await MainActor.run {
                if best.isEmpty {
                    let msg = results.isEmpty
                        ? "All models failed"
                        : "All \(results.count) models failed quality check"
                    findModelsStatus?.stringValue = msg
                    findModelsStatus?.textColor = .systemRed
                } else {
                    // Set primary = best quality+speed, fallbacks = rest
                    modelField?.stringValue = best[0].id
                    if best.count > 1 {
                        let fallbacks = best.dropFirst().map { $0.id }
                        fallbackModelsField?.stringValue = fallbacks.joined(separator: "\n")
                    }
                    let details = best.map { "\($0.latencyMs)ms/\(Int($0.quality * 100))%" }.joined(separator: ", ")
                    var status = "✓ Top \(best.count): \(details)"
                    if droppedCount > 0 {
                        status += " (\(droppedCount) dropped)"
                    }
                    findModelsStatus?.stringValue = status
                    findModelsStatus?.textColor = .systemGreen
                }
                findModelsButton?.isEnabled = true
            }
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
        case .openrouter: return Config.DefaultModels.openrouter
        }
    }

    @objc private func testConnection() {
        let provider = selectedProvider()
        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)

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
        case .openrouter:
            return CorrectMeApp.fetchOpenRouterModels(apiKey: key) != nil
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

    private func makeWritingStyleTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "style")
        item.label = "Writing Style"
        let view = NSView()

        let contentW = W - pad * 2
        var y: CGFloat = 340

        // ── Global Style ── header + Clear button on the same row
        let globalLabel = makeSectionHeader("Global Style")
        globalLabel.frame = NSRect(x: pad, y: y, width: contentW - 52, height: 18)
        view.addSubview(globalLabel)

        let clearBtn = NSButton(title: "Reset", target: self, action: #selector(clearStyle))
        clearBtn.bezelStyle = .rounded
        clearBtn.font = .systemFont(ofSize: 11)
        clearBtn.controlSize = .small
        clearBtn.frame = NSRect(x: W - pad - 58, y: y - 1, width: 58, height: 20)
        clearBtn.tag = 801  // tag so we can find it for feedback
        view.addSubview(clearBtn)
        y -= 22

        let desc = makeDescriptionLabel("Applied to every correction unless overridden by a per-app style.")
        desc.frame = NSRect(x: pad, y: y, width: contentW, height: 16)
        view.addSubview(desc)
        y -= 24

        // Taller scrollable text view
        let scrollH: CGFloat = 120
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

        // Pre-fill with saved value, falling back to the default.
        // The field is never empty — Clear resets to the default rather than blanking.
        tv.string = config.writingStyle ?? defaultWritingStyle

        y -= scrollH + 8

        // Subtle hint below the text area
        let hint = NSTextField(labelWithString: "Instructions are appended to the AI prompt. Reset restores the default.")
        hint.frame = NSRect(x: pad, y: y, width: contentW, height: 28)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        view.addSubview(hint)
        y -= 34

        // ── Per-App Styles ──
        view.addSubview(makeSeparator(x: pad, y: y, width: contentW))
        y -= 20

        let perAppLabel = makeSectionHeader("Per-App Styles")
        perAppLabel.frame = NSRect(x: pad, y: y, width: 120, height: 18)
        view.addSubview(perAppLabel)

        let perAppDesc = makeDescriptionLabel("Override the global style for specific apps:")
        perAppDesc.frame = NSRect(x: pad + 124, y: y, width: contentW - 260, height: 18)
        view.addSubview(perAppDesc)

        // "Add App…" button in header row — text + icon so it's clearly visible
        let addBtn = NSButton(title: " Add App…", target: self, action: #selector(addPerAppStyle))
        addBtn.bezelStyle = .rounded
        addBtn.font = .systemFont(ofSize: 11)
        if #available(macOS 11.0, *),
           let img = NSImage(systemSymbolName: "plus", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
            addBtn.image = img.withSymbolConfiguration(cfg)
            addBtn.imagePosition = .imageLeft
        }
        let btnW: CGFloat = 90
        addBtn.frame = NSRect(x: contentW + pad - btnW, y: y - 3, width: btnW, height: 22)
        view.addSubview(addBtn)

        y -= 26

        // Container for per-app entries (scrollable) — taller thanks to removed preset buttons
        let containerH: CGFloat = 138
        let containerScroll = NSScrollView(frame: NSRect(x: pad, y: y - containerH, width: contentW, height: containerH))
        containerScroll.hasVerticalScroller = true
        containerScroll.borderType = .bezelBorder
        containerScroll.drawsBackground = true

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: containerScroll.contentSize.width, height: containerH))
        containerScroll.documentView = containerView
        view.addSubview(containerScroll)
        perAppStylesContainer = containerView

        // Load per-app entries
        perAppEntries = (config.perAppStyles ?? [:]).map { (bundleId: $0.key, style: $0.value) }
            .sorted { $0.bundleId < $1.bundleId }
        rebuildPerAppList()

        y -= containerH + 6

        item.view = view
        return item
    }

    // MARK: - Per-App Styles Helpers

    /// Creates a scrollable multi-line NSTextView for style input, matching the Global Style editor.
    private func makeStyleTextView(frame: NSRect, initialText: String, placeholder: String) -> (scrollView: NSScrollView, textView: NSTextView) {
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize), textContainer: textContainer)
        tv.isEditable = true
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 12)
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 5)
        tv.string = initialText
        scrollView.documentView = tv

        // Placeholder overlay (shown when empty)
        let ph = NSTextField(labelWithString: placeholder)
        ph.frame = NSRect(x: 7, y: frame.height - 22, width: frame.width - 14, height: 18)
        ph.font = .systemFont(ofSize: 12)
        ph.textColor = .placeholderTextColor
        ph.isEditable = false
        ph.isBezeled = false
        ph.drawsBackground = false
        ph.isHidden = !initialText.isEmpty
        scrollView.addSubview(ph)

        // Hide placeholder when user starts typing (via notification)
        NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: tv, queue: .main) { _ in
            ph.isHidden = !tv.string.isEmpty
        }

        return (scrollView, tv)
    }

    /// Resolves a bundle ID to a human-readable app name and icon.
    private func appDisplayInfo(for bundleId: String) -> (name: String, icon: NSImage?) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            var name = FileManager.default.displayName(atPath: url.path)
            if name.lowercased().hasSuffix(".app") { name = String(name.dropLast(4)) }
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return (name, icon)
        }
        // Fallback: use last bundle ID component as name
        let fallback = bundleId.split(separator: ".").last.map(String.init) ?? bundleId
        return (fallback, nil)
    }

    private func rebuildPerAppList() {
        guard let container = perAppStylesContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let rowH: CGFloat = 36
        let totalH = max(CGFloat(perAppEntries.count) * rowH, container.superview?.frame.height ?? 80)
        container.frame = NSRect(x: 0, y: 0, width: container.frame.width, height: totalH)
        let cw = container.frame.width

        for (i, entry) in perAppEntries.enumerated() {
            let y = totalH - CGFloat(i + 1) * rowH
            let info = appDisplayInfo(for: entry.bundleId)

            // App icon
            let iconView = NSImageView(frame: NSRect(x: 8, y: y + 8, width: 20, height: 20))
            if let icon = info.icon {
                iconView.image = icon
            } else {
                // Placeholder gear icon when app not found
                if #available(macOS 11.0, *) {
                    iconView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
                }
            }
            iconView.imageScaling = .scaleProportionallyUpOrDown
            container.addSubview(iconView)

            // App name
            let nameLabel = NSTextField(labelWithString: info.name)
            nameLabel.frame = NSRect(x: 34, y: y + 11, width: 170, height: 16)
            nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
            nameLabel.textColor = .labelColor
            nameLabel.lineBreakMode = .byTruncatingTail
            container.addSubview(nameLabel)

            // Style text (leave 50px on right for edit + × buttons)
            let styleLabel = NSTextField(labelWithString: entry.style)
            styleLabel.frame = NSRect(x: 210, y: y + 11, width: cw - 264, height: 16)
            styleLabel.font = .systemFont(ofSize: 11)
            styleLabel.textColor = .secondaryLabelColor
            styleLabel.lineBreakMode = .byTruncatingTail
            container.addSubview(styleLabel)

            // ✏️ edit button
            let editBtn = NSButton(frame: NSRect(x: cw - 50, y: y + 8, width: 20, height: 20))
            if #available(macOS 11.0, *),
               let editImg = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Edit") {
                editBtn.image = editImg
                editBtn.imagePosition = .imageOnly
                editBtn.isBordered = false
                editBtn.contentTintColor = .secondaryLabelColor
            } else {
                editBtn.title = "✏️"
                editBtn.bezelStyle = .inline
            }
            editBtn.tag = i
            editBtn.target = self
            editBtn.action = #selector(editPerAppRowAtTag(_:))
            container.addSubview(editBtn)

            // × remove button
            let xBtn = NSButton(frame: NSRect(x: cw - 26, y: y + 8, width: 20, height: 20))
            if #available(macOS 11.0, *),
               let xImg = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove") {
                xBtn.image = xImg
                xBtn.imagePosition = .imageOnly
                xBtn.isBordered = false
                xBtn.contentTintColor = .tertiaryLabelColor
            } else {
                xBtn.title = "×"
                xBtn.bezelStyle = .inline
                xBtn.font = .systemFont(ofSize: 13)
            }
            xBtn.tag = i
            xBtn.target = self
            xBtn.action = #selector(removePerAppRowAtTag(_:))
            container.addSubview(xBtn)

            // Row separator
            if i < perAppEntries.count - 1 {
                let sep = NSView(frame: NSRect(x: 8, y: y, width: cw - 16, height: 1))
                sep.wantsLayer = true
                sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
                container.addSubview(sep)
            }
        }

        if perAppEntries.isEmpty {
            let placeholder = NSTextField(labelWithString: "No per-app styles configured")
            placeholder.frame = NSRect(x: 4, y: (totalH - 20) / 2, width: cw - 8, height: 20)
            placeholder.font = .systemFont(ofSize: 11)
            placeholder.textColor = .tertiaryLabelColor
            placeholder.alignment = .center
            container.addSubview(placeholder)
        }
    }

    @objc private func removePerAppRowAtTag(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0, idx < perAppEntries.count else { return }
        let entry = perAppEntries[idx]
        let appName = appDisplayInfo(for: entry.bundleId).name

        let alert = NSAlert()
        alert.messageText = "Remove style for \"\(appName)\"?"
        alert.informativeText = "The custom writing style for this app will be removed. The global style will be used instead."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        perAppEntries.remove(at: idx)
        rebuildPerAppList()
    }

    @objc private func editPerAppRowAtTag(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0, idx < perAppEntries.count else { return }

        if let existing = editAppPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        editingIndex = idx
        let entry = perAppEntries[idx]
        let info = appDisplayInfo(for: entry.bundleId)

        let W: CGFloat = 420
        let H: CGFloat = 240
        let pad: CGFloat = 20
        let contentW = W - pad * 2

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Edit Style — \(info.name)"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.minSize = NSSize(width: 340, height: 220)

        let cv = panel.contentView!

        // App row (icon + name)
        let appSectionLabel = NSTextField(labelWithString: "App")
        appSectionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        appSectionLabel.textColor = .secondaryLabelColor
        appSectionLabel.frame = NSRect(x: pad, y: H - 36, width: contentW, height: 14)
        cv.addSubview(appSectionLabel)

        let iconView = NSImageView(frame: NSRect(x: pad, y: H - 62, width: 20, height: 20))
        if let icon = info.icon {
            iconView.image = icon
        } else if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        cv.addSubview(iconView)

        let appNameLabel = NSTextField(labelWithString: info.name)
        appNameLabel.frame = NSRect(x: pad + 26, y: H - 61, width: contentW - 26, height: 18)
        appNameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        appNameLabel.textColor = .labelColor
        cv.addSubview(appNameLabel)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: H - 74, width: contentW, height: 1)
        cv.addSubview(sep)

        // Style label
        let styleLabel = NSTextField(labelWithString: "Writing Style")
        styleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        styleLabel.textColor = .secondaryLabelColor
        styleLabel.frame = NSRect(x: pad, y: H - 92, width: contentW, height: 14)
        cv.addSubview(styleLabel)

        // Multi-line text view (resizes with panel)
        let tvH: CGFloat = H - 92 - 48  // space between style label and buttons
        let (scrollView, tv) = makeStyleTextView(
            frame: NSRect(x: pad, y: 48, width: contentW, height: tvH),
            initialText: entry.style,
            placeholder: "e.g. casual tone, professional, no jargon"
        )
        scrollView.autoresizingMask = [.width, .height]
        cv.addSubview(scrollView)
        editAppStyleViewRef = tv

        // Buttons (pinned to bottom)
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelEditPerAppStyle))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        cancelBtn.frame = NSRect(x: W - pad - 162, y: 12, width: 72, height: 28)
        cv.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(confirmEditPerAppStyle))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        saveBtn.frame = NSRect(x: W - pad - 82, y: 12, width: 82, height: 28)
        cv.addSubview(saveBtn)

        editAppPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(tv)
        tv.selectAll(nil)
    }

    @objc private func confirmEditPerAppStyle() {
        guard let tv = editAppStyleViewRef,
              editingIndex >= 0, editingIndex < perAppEntries.count else { return }

        let style = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !style.isEmpty else {
            tv.enclosingScrollView?.layer?.borderWidth = 1
            tv.enclosingScrollView?.layer?.borderColor = NSColor.systemRed.cgColor
            return
        }

        perAppEntries[editingIndex].style = style
        editAppPanel?.close()
        editAppPanel = nil
        editAppStyleViewRef = nil
        editingIndex = -1
        rebuildPerAppList()
    }

    @objc private func cancelEditPerAppStyle() {
        editAppPanel?.close()
        editAppPanel = nil
        editAppStyleViewRef = nil
        editingIndex = -1
    }

    @objc private func addPerAppStyle() {
        if let existing = addAppPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let W: CGFloat = 420
        let H: CGFloat = 260
        let pad: CGFloat = 20
        let contentW = W - pad * 2

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Add Per-App Style"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.minSize = NSSize(width: 340, height: 240)

        let cv = panel.contentView!

        // App picker
        let appSectionLabel = NSTextField(labelWithString: "App")
        appSectionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        appSectionLabel.textColor = .secondaryLabelColor
        appSectionLabel.frame = NSRect(x: pad, y: H - 36, width: contentW, height: 14)
        cv.addSubview(appSectionLabel)

        let appPopUp = NSPopUpButton(frame: NSRect(x: pad, y: H - 64, width: contentW, height: 26))
        appPopUp.autoresizingMask = [.width]
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        appPopUp.addItem(withTitle: "Select a running app…")
        for app in runningApps {
            let name = app.localizedName ?? "Unknown"
            appPopUp.addItem(withTitle: name)
            appPopUp.lastItem?.representedObject = app.bundleIdentifier
            if let icon = app.icon {
                let thumb = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
                    icon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
                    return true
                }
                appPopUp.lastItem?.image = thumb
            }
        }
        cv.addSubview(appPopUp)
        addAppPopUpRef = appPopUp

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: H - 78, width: contentW, height: 1)
        cv.addSubview(sep)

        // Style label
        let styleLabel = NSTextField(labelWithString: "Writing Style")
        styleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        styleLabel.textColor = .secondaryLabelColor
        styleLabel.frame = NSRect(x: pad, y: H - 96, width: contentW, height: 14)
        cv.addSubview(styleLabel)

        // Multi-line text view
        let tvH: CGFloat = H - 96 - 48
        let (scrollView, tv) = makeStyleTextView(
            frame: NSRect(x: pad, y: 48, width: contentW, height: tvH),
            initialText: "",
            placeholder: "e.g. casual tone, professional, no jargon"
        )
        scrollView.autoresizingMask = [.width, .height]
        cv.addSubview(scrollView)
        addAppStyleViewRef = tv

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelAddPerAppStyle))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        cancelBtn.frame = NSRect(x: W - pad - 162, y: 12, width: 72, height: 28)
        cv.addSubview(cancelBtn)

        let addBtn = NSButton(title: "Add", target: self, action: #selector(confirmAddPerAppStyle))
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        addBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        addBtn.frame = NSRect(x: W - pad - 82, y: 12, width: 82, height: 28)
        cv.addSubview(addBtn)

        addAppPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(tv)
    }

    @objc private func confirmAddPerAppStyle() {
        guard let popup = addAppPopUpRef, let tv = addAppStyleViewRef else { return }

        guard popup.indexOfSelectedItem > 0,
              let bundleId = popup.selectedItem?.representedObject as? String else {
            popup.layer?.borderColor = NSColor.systemRed.cgColor
            return
        }

        let style = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !style.isEmpty else {
            tv.enclosingScrollView?.layer?.borderWidth = 1
            tv.enclosingScrollView?.layer?.borderColor = NSColor.systemRed.cgColor
            return
        }

        if let idx = perAppEntries.firstIndex(where: { $0.bundleId == bundleId }) {
            perAppEntries[idx].style = style
        } else {
            perAppEntries.append((bundleId: bundleId, style: style))
        }

        addAppPanel?.close()
        addAppPanel = nil
        addAppPopUpRef = nil
        addAppStyleViewRef = nil
        rebuildPerAppList()
    }

    @objc private func cancelAddPerAppStyle() {
        addAppPanel?.close()
        addAppPanel = nil
        addAppPopUpRef = nil
        addAppStyleViewRef = nil
    }

    @objc private func clearStyle() {
        styleTextView.string = defaultWritingStyle
        styleTextView.selectAll(nil)  // select all so user can immediately type replacement

        // Brief visual feedback on the Reset button
        if let btn = styleTextView.window?.contentView?.viewWithTag(801) as? NSButton {
            btn.title = "✓ Reset"
            btn.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                btn.title = "Reset"
                btn.isEnabled = true
            }
        }
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

        let key = currentAPIKeyValue().trimmingCharacters(in: .whitespacesAndNewlines)
        if providerNeedsAPIKey(config.aiProvider) && !key.isEmpty {
            switch config.aiProvider {
            case .claude: config.anthropicAPIKey = key
            case .gemini: config.geminiAPIKey = key
            case .codex: config.openaiAPIKey = key
            case .openrouter: config.openrouterAPIKey = key
            default: break
            }
        }

        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.model = model.isEmpty ? nil : model

        // Save fallback models (one per line)
        let fbText = fallbackModelsField?.stringValue ?? ""
        let fallbacks = fbText.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        config.fallbackModels = fallbacks.isEmpty ? nil : fallbacks

        let style = styleTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        config.writingStyle = style.isEmpty ? defaultWritingStyle : style

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

        // Restart daemon so new config takes effect immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MenuBarManager.shared.restartDaemon()
        }
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
