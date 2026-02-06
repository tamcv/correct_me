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
            print("❌ Failed to create status bar button")
            return
        }

        print("[DEBUG] Status bar button created successfully")
        updateIcon(for: .idle)

        menu = NSMenu()
        menu?.delegate = self
        print("[DEBUG] Menu created: \(menu != nil)")
        
        statusItem?.menu = menu
        print("[DEBUG] Menu assigned to statusItem: \(statusItem?.menu != nil)")
        
        updateMenu()
        
        print("✓ Menu bar initialized with \(menu?.items.count ?? 0) items")
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
            print("⚠️  Menu is nil in updateMenu()")
            return
        }
        print("[DEBUG] updateMenu() called")
        menu.removeAllItems()

        // Header
        let headerItem = NSMenuItem(title: "CorrectMe v\(AppVersion.current)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

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

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit CorrectMe",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        print("[DEBUG] Menu updated with \(menu.items.count) items")
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
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Run 'correctme setup' from terminal to configure CorrectMe."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSMenuDelegate
extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        print("[DEBUG] Menu will open - menu has \(menu.items.count) items")
    }
    
    func menuDidClose(_ menu: NSMenu) {
        print("[DEBUG] Menu did close")
    }
}
