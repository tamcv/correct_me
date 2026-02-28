import AppKit
import Foundation

/// Feedback window: category picker, description, debug info.
/// Sends feedback via Telegram Bot API. Falls back to mailto: if unconfigured.
/// Styled to match modern macOS Sequoia design language.
class FeedbackWindowController: NSObject, NSWindowDelegate {
    static let shared = FeedbackWindowController()

    private var window: NSPanel?

    private var categoryPopUp: NSPopUpButton!
    private var descriptionTextView: NSTextView!
    private var debugInfoTextView: NSTextView!
    private var sendButton: NSButton!
    private var statusLabel: NSTextField!

    private let W: CGFloat = 500
    private let H: CGFloat = 480
    private let pad: CGFloat = 24

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
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Send Feedback"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .visible
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.backgroundColor = .windowBackgroundColor

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
        let contentW = W - pad * 2
        var y: CGFloat = H - 24

        // Category section
        y -= 20
        let catHeader = makeSectionHeader("Category")
        catHeader.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        root.addSubview(catHeader)
        y -= 30

        categoryPopUp = NSPopUpButton(frame: NSRect(x: pad, y: y, width: contentW, height: 26), pullsDown: false)
        categoryPopUp.controlSize = .large
        for cat in categories {
            categoryPopUp.addItem(withTitle: cat)
        }
        root.addSubview(categoryPopUp)
        y -= 36

        // Description section
        let descHeader = makeSectionHeader("Description")
        descHeader.frame = NSRect(x: pad, y: y, width: contentW, height: 18)
        root.addSubview(descHeader)
        y -= 8

        let descScroll = NSScrollView(frame: NSRect(x: pad, y: y - 110, width: contentW, height: 110))
        descScroll.hasVerticalScroller = true
        descScroll.borderType = .bezelBorder
        descScroll.scrollerStyle = .overlay

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
        descTV.textContainerInset = NSSize(width: 6, height: 8)
        descScroll.documentView = descTV
        root.addSubview(descScroll)
        descriptionTextView = descTV
        y -= 126

        // Debug info section
        let debugHeader = makeSectionHeader("Debug Info")
        debugHeader.frame = NSRect(x: pad, y: y, width: 80, height: 18)
        root.addSubview(debugHeader)

        let debugHint = NSTextField(labelWithString: "Auto-filled, included in report")
        debugHint.font = .systemFont(ofSize: 11)
        debugHint.textColor = .tertiaryLabelColor
        debugHint.frame = NSRect(x: pad + 84, y: y, width: contentW - 84, height: 18)
        root.addSubview(debugHint)
        y -= 8

        let debugScroll = NSScrollView(frame: NSRect(x: pad, y: y - 100, width: contentW, height: 100))
        debugScroll.hasVerticalScroller = true
        debugScroll.borderType = .bezelBorder
        debugScroll.scrollerStyle = .overlay

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
        debugTV.textContainerInset = NSSize(width: 6, height: 8)
        debugTV.backgroundColor = NSColor.controlBackgroundColor
        debugScroll.documentView = debugTV
        root.addSubview(debugScroll)
        debugInfoTextView = debugTV
        debugTV.string = buildDebugInfo()

        // Bottom buttons
        let btnY: CGFloat = 16

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.controlSize = .large
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: pad, y: btnY, width: 90, height: 32)
        root.addSubview(cancelBtn)

        let copyBtn = NSButton(title: "Copy Debug Info", target: self, action: #selector(copyDebugInfo))
        copyBtn.bezelStyle = .rounded
        copyBtn.controlSize = .large
        copyBtn.frame = NSRect(x: pad + 100, y: btnY, width: 130, height: 32)
        root.addSubview(copyBtn)

        sendButton = NSButton(title: "Send Feedback", target: self, action: #selector(sendFeedback))
        sendButton.bezelStyle = .rounded
        sendButton.controlSize = .large
        sendButton.keyEquivalent = "\r"
        sendButton.frame = NSRect(x: W - pad - 140, y: btnY, width: 140, height: 32)
        root.addSubview(sendButton)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: pad, y: btnY + 38, width: contentW, height: 18)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.alignment = .center
        statusLabel.isHidden = true
        root.addSubview(statusLabel)
    }

    // MARK: - Helpers

    private func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
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

    private func escapeMarkdown(_ text: String) -> String {
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
