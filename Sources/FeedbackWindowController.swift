import AppKit
import Foundation

/// Feedback window: category picker, description, debug info.
/// Sends feedback via Telegram Bot API. Falls back to mailto: if unconfigured.
class FeedbackWindowController: NSObject, NSWindowDelegate {
    static let shared = FeedbackWindowController()

    private var window: NSPanel?

    private var categoryPopUp: NSPopUpButton!
    private var descriptionTextView: NSTextView!
    private var debugInfoTextView: NSTextView!
    private var sendButton: NSButton!
    private var statusLabel: NSTextField!

    private let W: CGFloat = 480
    private let H: CGFloat = 440
    private let pad: CGFloat = 20

    private let categories = ["Bug Report", "Feature Request", "Other"]

    private override init() { super.init() }

    // MARK: - Show

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Send Feedback"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        let root = NSView(frame: panel.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        panel.contentView = root

        buildUI(in: root)

        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI

    private func buildUI(in root: NSView) {
        var y: CGFloat = H - 40

        // Category
        let catLabel = NSTextField(labelWithString: "Category:")
        catLabel.frame = NSRect(x: pad, y: y, width: 70, height: 20)
        catLabel.font = .systemFont(ofSize: 13)
        root.addSubview(catLabel)

        categoryPopUp = NSPopUpButton(frame: NSRect(x: 90, y: y - 2, width: 200, height: 26), pullsDown: false)
        for cat in categories {
            categoryPopUp.addItem(withTitle: cat)
        }
        root.addSubview(categoryPopUp)

        // Description
        y -= 36
        let descLabel = NSTextField(labelWithString: "Description:")
        descLabel.frame = NSRect(x: pad, y: y, width: 100, height: 20)
        descLabel.font = .systemFont(ofSize: 13)
        root.addSubview(descLabel)

        y -= 110
        let descScroll = NSScrollView(frame: NSRect(x: pad, y: y, width: W - pad * 2, height: 110))
        descScroll.hasVerticalScroller = true
        descScroll.borderType = .bezelBorder

        let descStorage = NSTextStorage()
        let descLayout = NSLayoutManager()
        descStorage.addLayoutManager(descLayout)
        let descContainer = NSTextContainer(size: NSSize(width: descScroll.contentSize.width, height: .greatestFiniteMagnitude))
        descContainer.widthTracksTextView = true
        descLayout.addTextContainer(descContainer)

        let descTV = NSTextView(frame: NSRect(origin: .zero, size: descScroll.contentSize), textContainer: descContainer)
        descTV.isEditable = true
        descTV.isRichText = false
        descTV.font = .systemFont(ofSize: 13)
        descTV.allowsUndo = true
        descTV.textContainerInset = NSSize(width: 4, height: 6)
        descScroll.documentView = descTV
        root.addSubview(descScroll)
        descriptionTextView = descTV

        // Debug info
        y -= 26
        let debugLabel = NSTextField(labelWithString: "Debug Info (auto-filled, included in report):")
        debugLabel.frame = NSRect(x: pad, y: y, width: W - pad * 2, height: 20)
        debugLabel.font = .systemFont(ofSize: 11)
        debugLabel.textColor = .secondaryLabelColor
        root.addSubview(debugLabel)

        y -= 100
        let debugScroll = NSScrollView(frame: NSRect(x: pad, y: y, width: W - pad * 2, height: 100))
        debugScroll.hasVerticalScroller = true
        debugScroll.borderType = .bezelBorder

        let debugStorage = NSTextStorage()
        let debugLayout = NSLayoutManager()
        debugStorage.addLayoutManager(debugLayout)
        let debugContainer = NSTextContainer(size: NSSize(width: debugScroll.contentSize.width, height: .greatestFiniteMagnitude))
        debugContainer.widthTracksTextView = true
        debugLayout.addTextContainer(debugContainer)

        let debugTV = NSTextView(frame: NSRect(origin: .zero, size: debugScroll.contentSize), textContainer: debugContainer)
        debugTV.isEditable = false
        debugTV.isRichText = false
        debugTV.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        debugTV.textContainerInset = NSSize(width: 4, height: 6)
        debugTV.backgroundColor = NSColor.controlBackgroundColor
        debugScroll.documentView = debugTV
        root.addSubview(debugScroll)
        debugInfoTextView = debugTV

        // Fill debug info
        debugTV.string = buildDebugInfo()

        // Buttons
        let btnY: CGFloat = 12

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: pad, y: btnY, width: 80, height: 28)
        root.addSubview(cancelBtn)

        let copyBtn = NSButton(title: "Copy Debug Info", target: self, action: #selector(copyDebugInfo))
        copyBtn.bezelStyle = .rounded
        copyBtn.frame = NSRect(x: pad + 90, y: btnY, width: 130, height: 28)
        root.addSubview(copyBtn)

        sendButton = NSButton(title: "Send Feedback", target: self, action: #selector(sendFeedback))
        sendButton.bezelStyle = .rounded
        sendButton.keyEquivalent = "\r"
        sendButton.frame = NSRect(x: W - pad - 140, y: btnY, width: 140, height: 28)
        root.addSubview(sendButton)

        // Status label (hidden by default)
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: pad, y: btnY + 32, width: W - pad * 2, height: 18)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.alignment = .center
        statusLabel.isHidden = true
        root.addSubview(statusLabel)
    }

    // MARK: - Debug Info

    private func buildDebugInfo() -> String {
        let config = Config.load()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        var lines: [String] = [
            "CorrectMe \(AppVersion.fullVersion)",
            "macOS \(osVersion)",
            "Provider: \(config.aiProvider.rawValue)",
            "Model: \(config.model ?? "default")",
        ]

        let errors = ErrorLog.shared.getErrors()
        if !errors.isEmpty {
            lines.append("")
            lines.append("Recent errors:")
            for error in errors.prefix(3) {
                lines.append("  [\(error.category.rawValue)] \(error.message) (\(error.timeAgo))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func sendFeedback() {
        let config = Config.load()
        let category = categories[categoryPopUp.indexOfSelectedItem]
        let description = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let debugInfo = debugInfoTextView.string

        guard !description.isEmpty else {
            showStatus("Please enter a description.", color: .systemRed)
            return
        }

        // Try Telegram first, fall back to email
        if let token = config.telegramBotToken, !token.isEmpty,
           let chatId = config.telegramChatId, !chatId.isEmpty {
            sendViaTelegram(token: token, chatId: chatId, category: category, description: description, debugInfo: debugInfo)
        } else {
            sendViaEmail(category: category, description: description, debugInfo: debugInfo)
        }
    }

    // MARK: - Telegram

    private func sendViaTelegram(token: String, chatId: String, category: String, description: String, debugInfo: String) {
        sendButton.isEnabled = false
        showStatus("Sending...", color: .secondaryLabelColor)

        let emoji: String
        switch category {
        case "Bug Report": emoji = "🐛"
        case "Feature Request": emoji = "💡"
        default: emoji = "💬"
        }

        let text = """
        \(emoji) *CorrectMe Feedback*

        *Category:* \(escapeMarkdown(category))
        *Description:*
        \(escapeMarkdown(description))

        ```
        \(debugInfo)
        ```
        """

        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        guard let url = URL(string: urlString) else {
            showStatus("Invalid bot token.", color: .systemRed)
            sendButton.isEnabled = true
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "Markdown",
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            showStatus("Failed to build request.", color: .systemRed)
            sendButton.isEnabled = true
            return
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.sendButton.isEnabled = true

                if let error = error {
                    self?.showStatus("Failed: \(error.localizedDescription)", color: .systemRed)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showStatus("No response from Telegram.", color: .systemRed)
                    return
                }

                if httpResponse.statusCode == 200 {
                    self?.showStatus("Feedback sent! Thank you.", color: .systemGreen)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.window?.close()
                    }
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown error"
                    debugLog("Telegram feedback error: \(httpResponse.statusCode) \(body)")
                    self?.showStatus("Telegram error (\(httpResponse.statusCode)). Try again.", color: .systemRed)
                }
            }
        }.resume()
    }

    /// Escape Markdown special characters for Telegram.
    private func escapeMarkdown(_ text: String) -> String {
        // In Markdown mode, escape _ * [ ] ( ) ~ ` > # + - = | { } . !
        // But keep it simple — only escape the most common ones that break formatting
        return text
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "[", with: "\\[")
    }

    // MARK: - Email Fallback

    private func sendViaEmail(category: String, description: String, debugInfo: String) {
        let subject = "CorrectMe Feedback: \(category)"
        let body = "\(description)\n\n---\n\(debugInfo)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "feedback@correctme.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }

        window?.close()
    }

    // MARK: - Helpers

    @objc private func copyDebugInfo() {
        let debugInfo = debugInfoTextView.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo, forType: .string)

        if let root = window?.contentView {
            for subview in root.subviews {
                if let btn = subview as? NSButton, btn.title == "Copy Debug Info" {
                    btn.title = "Copied!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        btn.title = "Copy Debug Info"
                    }
                    break
                }
            }
        }
    }

    @objc private func cancel() {
        window?.close()
    }

    private func showStatus(_ message: String, color: NSColor) {
        statusLabel.stringValue = message
        statusLabel.textColor = color
        statusLabel.isHidden = false
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
