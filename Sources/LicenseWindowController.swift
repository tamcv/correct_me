import AppKit

/// Modal window for entering and activating a CorrectMe license key.
class LicenseWindowController: NSObject, NSWindowDelegate {
    static let shared = LicenseWindowController()

    private var window: NSPanel?
    private var trialBanner: NSTextField?
    private var isTrialExpired = false

    private var emailField: NSTextField!
    private var licenseField: NSTextField!
    private var activateButton: NSButton!
    private var statusLabel: NSTextField!
    private var buyButton: NSButton!

    private let W: CGFloat = 480
    private let H: CGFloat = 380
    private let pad: CGFloat = 28

    private override init() { super.init() }

    func showWindow(trialExpired: Bool = false) {
        isTrialExpired = trialExpired

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let styleMask: NSWindow.StyleMask = trialExpired
            ? [.titled]
            : [.titled, .closable]

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = trialExpired ? "Trial Expired — Activate CorrectMe" : "Activate CorrectMe"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.backgroundColor = .windowBackgroundColor

        buildUI(in: panel.contentView!)

        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Pre-populate if already activated
        if let info = LicenseManager.shared.licenseInfo {
            emailField.stringValue = info.email
            licenseField.stringValue = info.licenseKey
            showActivated(email: info.email)
        }
    }

    // MARK: - UI

    private func buildUI(in root: NSView) {
        var y: CGFloat = H - pad

        // Trial banner (shown when trial is running or expired)
        if !LicenseManager.shared.isActivated {
            let bannerText: String
            let bannerColor: NSColor
            if isTrialExpired {
                bannerText = "Your 14-day trial has expired. Activate a license to continue using CorrectMe."
                bannerColor = NSColor.systemRed.withAlphaComponent(0.12)
            } else if let days = LicenseManager.shared.trialDaysRemaining {
                bannerText = "Trial: \(days) day\(days == 1 ? "" : "s") remaining out of 14. Activate to unlock permanently."
                bannerColor = NSColor.systemOrange.withAlphaComponent(0.12)
            } else {
                bannerText = ""
                bannerColor = .clear
            }

            if !bannerText.isEmpty {
                let banner = NSBox()
                banner.boxType = .custom
                banner.fillColor = bannerColor
                banner.borderColor = .clear
                banner.cornerRadius = 6
                banner.frame = NSRect(x: pad, y: y - 44, width: W - pad * 2, height: 44)
                root.addSubview(banner)

                let bannerLabel = NSTextField(wrappingLabelWithString: bannerText)
                bannerLabel.font = .systemFont(ofSize: 11)
                bannerLabel.textColor = isTrialExpired ? .systemRed : .systemOrange
                bannerLabel.frame = NSRect(x: 10, y: 8, width: W - pad * 2 - 20, height: 28)
                banner.addSubview(bannerLabel)
                trialBanner = bannerLabel
                y -= 56
            }
        }

        // Title
        let title = NSTextField(labelWithString: "Activate Your License")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.frame = NSRect(x: pad, y: y - 22, width: W - pad * 2, height: 22)
        root.addSubview(title)
        y -= 40

        // Subtitle
        let sub = NSTextField(wrappingLabelWithString: "Enter the email you used to purchase and your license key.")
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = .secondaryLabelColor
        sub.frame = NSRect(x: pad, y: y - 32, width: W - pad * 2, height: 32)
        root.addSubview(sub)
        y -= 50

        // Email
        let emailLabel = NSTextField(labelWithString: "Purchase Email")
        emailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        emailLabel.frame = NSRect(x: pad, y: y - 16, width: W - pad * 2, height: 16)
        root.addSubview(emailLabel)
        y -= 24

        emailField = NSTextField(frame: NSRect(x: pad, y: y - 24, width: W - pad * 2, height: 24))
        emailField.placeholderString = "you@example.com"
        emailField.font = .systemFont(ofSize: 13)
        emailField.controlSize = .large
        root.addSubview(emailField)
        y -= 38

        // License Key
        let keyLabel = NSTextField(labelWithString: "License Key")
        keyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        keyLabel.frame = NSRect(x: pad, y: y - 16, width: W - pad * 2, height: 16)
        root.addSubview(keyLabel)
        y -= 24

        licenseField = NSTextField(frame: NSRect(x: pad, y: y - 24, width: W - pad * 2, height: 24))
        licenseField.placeholderString = "XXXX-XXXX-XXXX-XXXX"
        licenseField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        licenseField.controlSize = .large
        root.addSubview(licenseField)
        y -= 38

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: pad, y: y - 20, width: W - pad * 2 - 150, height: 20)
        root.addSubview(statusLabel)

        // Activate button
        activateButton = NSButton(title: "Activate", target: self, action: #selector(activateTapped))
        activateButton.bezelStyle = .rounded
        activateButton.keyEquivalent = "\r"
        activateButton.controlSize = .large
        activateButton.frame = NSRect(x: W - pad - 110, y: y - 28, width: 110, height: 28)
        root.addSubview(activateButton)
        y -= 44

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: pad, y: y - 1, width: W - pad * 2, height: 1)
        root.addSubview(sep)
        y -= 18

        // Buy link
        let noKeyLabel = NSTextField(labelWithString: "Don't have a license yet?")
        noKeyLabel.font = .systemFont(ofSize: 11)
        noKeyLabel.textColor = .secondaryLabelColor
        noKeyLabel.frame = NSRect(x: pad, y: y - 16, width: 200, height: 16)
        root.addSubview(noKeyLabel)

        buyButton = NSButton(title: "Buy CorrectMe →", target: self, action: #selector(buyTapped))
        buyButton.bezelStyle = .inline
        buyButton.isBordered = false
        buyButton.font = .systemFont(ofSize: 11)
        if let cell = buyButton.cell as? NSButtonCell {
            cell.alignment = .left
        }
        buyButton.frame = NSRect(x: pad + 186, y: y - 16, width: 160, height: 16)
        root.addSubview(buyButton)
    }

    // MARK: - Actions

    @objc private func activateTapped() {
        let email = emailField.stringValue
        let key = licenseField.stringValue

        activateButton.isEnabled = false
        statusLabel.stringValue = "Validating…"
        statusLabel.textColor = .secondaryLabelColor

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LicenseManager.shared.activate(email: email, licenseKey: key)
            DispatchQueue.main.async {
                self?.activateButton.isEnabled = true
                switch result {
                case .success(let info):
                    self?.showActivated(email: info.email)
                case .failure(let err):
                    self?.statusLabel.stringValue = "✕ \(err.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }

    private func showActivated(email: String) {
        statusLabel.stringValue = "✓ Activated — thank you!"
        statusLabel.textColor = .systemGreen
        activateButton.title = "Activated"
        activateButton.isEnabled = false

        // Hide trial banner on successful activation
        trialBanner?.isHidden = true

        // Refresh the menu bar to reflect new license state
        MenuBarManager.shared.updateMenuPublic()

        // Restore accessory policy and close window after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            NSApp.setActivationPolicy(.accessory)
            self?.window?.close()
        }
    }

    @objc private func buyTapped() {
        // Replace with your actual website URL
        if let url = URL(string: "https://correctme.app/#pricing") {
            NSWorkspace.shared.open(url)
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
