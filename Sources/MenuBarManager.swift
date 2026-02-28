import Cocoa
import Foundation

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private override init() {
        super.init()
        setupMenuBar()
        setupObservers()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard statusItem?.button != nil else {
            debugLog("Failed to create status bar button")
            return
        }

        debugLog("Status bar button created successfully")
        updateIcon(for: .idle)

        menu = NSMenu()
        menu?.delegate = self
        debugLog("Menu created: \(menu != nil)")

        statusItem?.menu = menu
        debugLog("Menu assigned to statusItem: \(statusItem?.menu != nil)")

        updateMenu()

        debugLog("Menu bar initialized with \(menu?.items.count ?? 0) items")
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStatusChanged),
            name: .statusChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleErrorLogUpdated),
            name: .errorLogUpdated,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHistoryUpdated),
            name: .correctionHistoryUpdated,
            object: nil
        )
    }

    @objc private func handleStatusChanged(_ notification: Notification) {
        guard let status = notification.object as? AppStatus else { return }
        DispatchQueue.main.async {
            self.updateIcon(for: status)
            self.updateMenu()
        }
    }

    @objc private func handleErrorLogUpdated() {
        DispatchQueue.main.async {
            self.updateMenu()
        }
    }

    @objc private func handleHistoryUpdated() {
        DispatchQueue.main.async {
            self.updateMenu()
        }
    }

    private func updateIcon(for status: AppStatus) {
        guard let button = statusItem?.button else { return }

        // Always use pencil.and.outline as the main icon
        let iconName = "pencil.and.outline"
        
        if let image = createStatusImage(systemName: iconName) {
            button.image = image
            
            // Add status indicator as text suffix
            switch status {
            case .idle:
                button.title = ""
            case .processing:
                button.title = " ⏳"
            case .success:
                button.title = " ✓"
            case .error:
                button.title = " !"
            }
        } else {
            // Fallback if SF Symbol not available
            button.image = nil
            switch status {
            case .idle:
                button.title = "CM"
            case .processing:
                button.title = "CM ⏳"
            case .success:
                button.title = "CM ✓"
            case .error:
                button.title = "CM !"
            }
        }
    }

    private func createStatusImage(systemName: String) -> NSImage? {
        // Try to use SF Symbol (macOS 11+)
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: "CorrectMe") {
                let configuredImage = image.withSymbolConfiguration(config)

                // Create a template image that respects the menu bar appearance
                configuredImage?.isTemplate = true
                return configuredImage
            }
        }

        // Fallback: return nil and button.title will be used
        return nil
    }

    private func updateMenu() {
        guard let menu = menu else {
            debugLog("Menu is nil in updateMenu()")
            return
        }
        debugLog("updateMenu() called")
        menu.removeAllItems()

        // Header
        let headerItem = NSMenuItem(title: "CorrectMe v\(AppVersion.current)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Provider and model info
        let cfg = Config.load()
        let modelName = cfg.model ?? "(default)"
        let providerItem = NSMenuItem(
            title: "Provider: \(cfg.aiProvider.rawValue) · \(modelName)",
            action: nil,
            keyEquivalent: ""
        )
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        let status = StatusManager.shared.currentStatus
        let statusItem = NSMenuItem(title: "Status: \(status.rawValue)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Last correction time
        if let timeAgo = StatusManager.shared.lastCorrectionTimeAgo {
            let timeItem = NSMenuItem(title: "Last correction: \(timeAgo)", action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Correction history (show max 5 in menu)
        let history = CorrectionHistory.shared.getEntries()
        if !history.isEmpty {
            let histHeaderItem = NSMenuItem(title: "📜 History (\(history.count))", action: nil, keyEquivalent: "")
            histHeaderItem.isEnabled = false
            menu.addItem(histHeaderItem)

            for (index, entry) in history.prefix(5).enumerated() {
                let origSnippet = String(entry.originalText.prefix(30))
                    .replacingOccurrences(of: "\n", with: " ")
                let corrSnippet = String(entry.correctedText.prefix(30))
                    .replacingOccurrences(of: "\n", with: " ")
                let ellipsis = entry.originalText.count > 30 ? "…" : ""
                let title = "  \(origSnippet)\(ellipsis) → \(corrSnippet)"
                let item = NSMenuItem(
                    title: title,
                    action: #selector(showHistoryDetail(_:)),
                    keyEquivalent: ""
                )
                item.tag = index
                item.target = self
                menu.addItem(item)

                let timeItem = NSMenuItem(title: "    \(entry.timeAgo)", action: nil, keyEquivalent: "")
                timeItem.isEnabled = false
                menu.addItem(timeItem)
            }

            if history.count > 5 {
                let viewAllItem = NSMenuItem(
                    title: "  View All History…",
                    action: #selector(viewAllHistory),
                    keyEquivalent: ""
                )
                viewAllItem.target = self
                menu.addItem(viewAllItem)
            }

            let clearHistItem = NSMenuItem(
                title: "  Clear History",
                action: #selector(clearHistory),
                keyEquivalent: ""
            )
            clearHistItem.target = self
            menu.addItem(clearHistItem)

            menu.addItem(NSMenuItem.separator())
        }

        // Recent errors
        let errors = ErrorLog.shared.getErrors()
        if !errors.isEmpty {
            let errorsHeaderItem = NSMenuItem(title: "📋 Recent Errors (\(errors.count))", action: nil, keyEquivalent: "")
            errorsHeaderItem.isEnabled = false
            menu.addItem(errorsHeaderItem)

            for (index, error) in errors.prefix(5).enumerated() {
                let errorText = error.message.prefix(50)
                let displayText = errorText.count < error.message.count ? "\(errorText)..." : String(errorText)
                let errorItem = NSMenuItem(
                    title: "  • \(displayText)",
                    action: #selector(showErrorDetail(_:)),
                    keyEquivalent: ""
                )
                errorItem.tag = index
                errorItem.target = self
                menu.addItem(errorItem)

                // Submenu for time
                let timeItem = NSMenuItem(title: "    \(error.timeAgo)", action: nil, keyEquivalent: "")
                timeItem.isEnabled = false
                menu.addItem(timeItem)
            }

            // Clear errors
            let clearItem = NSMenuItem(
                title: "  Clear Errors",
                action: #selector(clearErrors),
                keyEquivalent: ""
            )
            clearItem.target = self
            menu.addItem(clearItem)

            menu.addItem(NSMenuItem.separator())
        } else {
            let noErrorsItem = NSMenuItem(title: "No recent errors", action: nil, keyEquivalent: "")
            noErrorsItem.isEnabled = false
            menu.addItem(noErrorsItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Actions
        let restartItem = NSMenuItem(
            title: "🔄 Restart Daemon",
            action: #selector(restartDaemon),
            keyEquivalent: "r"
        )
        restartItem.target = self
        menu.addItem(restartItem)

        let prefsItem = NSMenuItem(
            title: "⚙️  Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let feedbackItem = NSMenuItem(
            title: "Send Feedback…",
            action: #selector(openFeedback),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        let privacyItem = NSMenuItem(
            title: "Privacy & Data…",
            action: #selector(showPrivacyInfo),
            keyEquivalent: ""
        )
        privacyItem.target = self
        menu.addItem(privacyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit CorrectMe",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        debugLog("Menu updated with \(menu.items.count) items")
    }

    @objc private func showErrorDetail(_ sender: NSMenuItem) {
        let errors = ErrorLog.shared.getErrors()
        guard sender.tag < errors.count else { return }

        let error = errors[sender.tag]

        // Activate app to show alert
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Error Details"
        alert.informativeText = """
        Category: \(error.category.rawValue)
        Time: \(error.timeAgo)

        \(error.message)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(error.message, forType: .string)
        }
    }

    @objc private func clearErrors() {
        ErrorLog.shared.clearErrors()
    }

    @objc private func showHistoryDetail(_ sender: NSMenuItem) {
        let entries = CorrectionHistory.shared.getEntries()
        guard sender.tag < entries.count else { return }

        let entry = entries[sender.tag]

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Correction — \(entry.timeAgo)"
        alert.informativeText = """
        Original:
        \(entry.originalText)

        Corrected:
        \(entry.correctedText)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Corrected")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(entry.correctedText, forType: .string)
        }
    }

    @objc private func clearHistory() {
        CorrectionHistory.shared.clear()
        // NSMenu auto-closes on any item action; re-open so the user sees the updated empty state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.statusItem?.button?.performClick(nil)
        }
    }

    @objc private func viewAllHistory() {
        let historyPath = CorrectionHistory.historyFilePath
        if FileManager.default.fileExists(atPath: historyPath.path) {
            NSWorkspace.shared.open(historyPath)
        }
    }

    @objc private func restartDaemon() {
        // Get the path to the correctme executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-c", "which correctme"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let correctmePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !correctmePath.isEmpty {
                // Found correctme, execute restart command
                let restartProcess = Process()
                restartProcess.executableURL = URL(fileURLWithPath: correctmePath)
                restartProcess.arguments = ["restart"]

                try restartProcess.run()

                // The daemon will exit, so no need to show success message
            } else {
                // Fallback: show alert if correctme not found
                showRestartInstructions()
            }
        } catch {
            // On error, show instructions
            showRestartInstructions()
        }
    }

    private func showRestartInstructions() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Restart Daemon"
        alert.informativeText = "Run 'correctme restart' from terminal to restart the daemon."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func openFeedback() {
        NSApp.activate(ignoringOtherApps: true)
        FeedbackWindowController.shared.showWindow()
    }

    @objc private func showPrivacyInfo() {
        let cfg = Config.load()
        let providerName = cfg.aiProvider.rawValue

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Privacy & Data Handling"
        alert.informativeText = """
        How CorrectMe handles your data:

        \u{2022} Your selected text is sent to the \(providerName) API for correction. No other data is transmitted.

        \u{2022} CorrectMe does not store, log, or share your text. Corrections are kept in local history only (~/.correctme/history.json).

        \u{2022} API keys are stored in the macOS Keychain, not in plaintext.

        \u{2022} No analytics, telemetry, or tracking is collected.

        \u{2022} Data retention depends on your AI provider's policy.

        For more details, visit the Privacy Policy.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View Privacy Policy")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/tamcv/correct_me/blob/main/PRIVACY.md") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func quitApp() {
        // Clean up PID file and exit with code 0.
        // With KeepAlive.SuccessfulExit=false in the LaunchAgent plist,
        // launchd will NOT restart the daemon on a successful (0) exit.
        // We call exit(0) directly instead of NSApplication.terminate() to
        // guarantee the exit code — terminate() may go through paths that
        // produce a non-zero exit, which would trigger a launchd restart.
        DaemonManager.removePIDFile()
        exit(0)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSMenuDelegate
extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        debugLog("Menu will open - menu has \(menu.items.count) items")
    }

    func menuDidClose(_ menu: NSMenu) {
        debugLog("Menu did close")
    }
}

// MARK: - Writing Style Preferences Window

class WritingStyleWindowController: NSObject, NSWindowDelegate {
    static let shared = WritingStyleWindowController()

    private var window: NSPanel?
    private var textView: NSTextView!

    private let presets: [(label: String, value: String)] = [
        ("More formal",       "Write in a formal, professional tone."),
        ("More casual",       "Write in a casual, friendly tone."),
        ("More concise",      "Make it shorter and more concise."),
        ("More polite",       "Use polite and respectful language."),
        ("Simpler language",  "Use simple, easy-to-understand words."),
        ("Funnier",           "Add a light, humorous touch."),
    ]

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Writing Style"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        panel.contentView = contentView

        buildUI(in: contentView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.window = panel

        // Load saved value
        let saved = Config.load().writingStyle ?? ""
        textView.string = saved
    }

    private func buildUI(in parent: NSView) {
        let padding: CGFloat = 20
        let width = parent.bounds.width

        // Description label
        let descLabel = NSTextField(labelWithString: "Customize how CorrectMe rewrites your text (applied to every correction):")
        descLabel.frame = NSRect(x: padding, y: parent.bounds.height - 56, width: width - padding * 2, height: 36)
        descLabel.autoresizingMask = [.width, .maxYMargin]
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 2
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        parent.addSubview(descLabel)

        // Scrollable text view
        let scrollY: CGFloat = 140
        let scrollH: CGFloat = parent.bounds.height - 56 - padding - scrollY
        let scrollView = NSScrollView(frame: NSRect(x: padding, y: scrollY, width: width - padding * 2, height: scrollH))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize), textContainer: textContainer)
        tv.autoresizingMask = [.width]
        tv.isEditable = true
        tv.isRichText = false
        tv.font = .systemFont(ofSize: 13)
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 6)
        scrollView.documentView = tv
        parent.addSubview(scrollView)
        self.textView = tv

        // Placeholder hint (shown when empty via overlay label)
        let placeholderLabel = NSTextField(labelWithString: "e.g. \"Write in a formal tone. Use bullet points when listing.\"")
        placeholderLabel.frame = NSRect(x: padding + 8, y: scrollY + scrollH - 26, width: width - padding * 2 - 16, height: 20)
        placeholderLabel.autoresizingMask = [.width, .maxYMargin]
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.isEditable = false
        placeholderLabel.isBezeled = false
        placeholderLabel.drawsBackground = false
        placeholderLabel.tag = 999
        parent.addSubview(placeholderLabel)

        // Preset label
        let presetsLabel = NSTextField(labelWithString: "Quick presets:")
        presetsLabel.frame = NSRect(x: padding, y: scrollY - 28, width: 100, height: 18)
        presetsLabel.autoresizingMask = [.maxYMargin]
        presetsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        presetsLabel.textColor = .secondaryLabelColor
        parent.addSubview(presetsLabel)

        // Preset buttons (2 explicit rows of 3, clear of action buttons at y=14-42)
        var bx: CGFloat = padding
        let by: CGFloat = 52   // 10px above action buttons top edge (14+28+10)
        let bh: CGFloat = 24
        let gap: CGFloat = 6
        for (i, preset) in presets.enumerated() {
            if i == 3 { bx = padding }  // Reset x for second row
            let btn = NSButton(title: preset.label, target: self, action: #selector(applyPreset(_:)))
            btn.bezelStyle = .rounded
            btn.font = .systemFont(ofSize: 11)
            btn.tag = i
            let bw = preset.label.size(withAttributes: [.font: btn.font!]).width + 24
            let row: CGFloat = i < 3 ? 1 : 0
            btn.frame = NSRect(x: bx, y: by + row * (bh + gap), width: bw, height: bh)
            btn.autoresizingMask = [.maxYMargin]
            parent.addSubview(btn)
            bx += bw + gap
        }

        // Save button
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: width - padding - 80, y: 14, width: 80, height: 28)
        saveBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        parent.addSubview(saveBtn)

        // Clear button
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearStyle))
        clearBtn.bezelStyle = .rounded
        clearBtn.frame = NSRect(x: width - padding - 170, y: 14, width: 80, height: 28)
        clearBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        parent.addSubview(clearBtn)

        // Cancel button
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: width - padding - 260, y: 14, width: 80, height: 28)
        cancelBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        parent.addSubview(cancelBtn)
    }

    @objc private func applyPreset(_ sender: NSButton) {
        let preset = presets[sender.tag]
        let current = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            textView.string = preset.value
        } else if !current.hasSuffix(preset.value) {
            textView.string = current + " " + preset.value
        }
        updatePlaceholderVisibility()
    }

    @objc private func save() {
        var config = Config.load()
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        config.writingStyle = text.isEmpty ? nil : text
        try? config.save()
        window?.close()
    }

    @objc private func clearStyle() {
        textView.string = ""
        updatePlaceholderVisibility()
    }

    @objc private func cancel() {
        window?.close()
    }

    private func updatePlaceholderVisibility() {
        let isEmpty = textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        window?.contentView?.viewWithTag(999)?.isHidden = !isEmpty
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updatePlaceholderVisibility()
    }
}
