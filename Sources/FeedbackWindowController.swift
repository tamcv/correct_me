import AppKit
import Foundation

/// Feedback window: category picker, description, debug info, open GitHub issue.
class FeedbackWindowController: NSObject, NSWindowDelegate {
    static let shared = FeedbackWindowController()

    private var window: NSPanel?

    private var categoryPopUp: NSPopUpButton!
    private var descriptionTextView: NSTextView!
    private var debugInfoTextView: NSTextView!

    private let W: CGFloat = 480
    private let H: CGFloat = 440
    private let pad: CGFloat = 20

    private static let repoURL = "https://github.com/tamcv/correct_me"

    private let categories: [(label: String, ghLabel: String)] = [
        ("Bug Report", "bug"),
        ("Feature Request", "enhancement"),
        ("Other", ""),
    ]

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
            categoryPopUp.addItem(withTitle: cat.label)
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

        let openBtn = NSButton(title: "Open GitHub Issue", target: self, action: #selector(openGitHubIssue))
        openBtn.bezelStyle = .rounded
        openBtn.keyEquivalent = "\r"
        openBtn.frame = NSRect(x: W - pad - 160, y: btnY, width: 160, height: 28)
        root.addSubview(openBtn)
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

    @objc private func openGitHubIssue() {
        let catIndex = categoryPopUp.indexOfSelectedItem
        let category = categories[catIndex]
        let description = descriptionTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let debugInfo = debugInfoTextView.string

        // Build issue title
        let title: String
        if description.count > 60 {
            title = String(description.prefix(57)) + "..."
        } else if description.isEmpty {
            title = "\(category.label): "
        } else {
            title = description.components(separatedBy: .newlines).first ?? description
        }

        // Build issue body — never include user correction text
        var body = ""
        if !description.isEmpty {
            body += "## Description\n\n\(description)\n\n"
        }
        body += "## Debug Info\n\n```\n\(debugInfo)\n```\n"

        // Build URL
        var urlString = "\(Self.repoURL)/issues/new?"
        var params: [String] = []
        params.append("title=\(urlEncode(title))")
        params.append("body=\(urlEncode(body))")
        if !category.ghLabel.isEmpty {
            params.append("labels=\(urlEncode(category.ghLabel))")
        }
        urlString += params.joined(separator: "&")

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        window?.close()
    }

    @objc private func copyDebugInfo() {
        let debugInfo = debugInfoTextView.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo, forType: .string)

        // Brief visual feedback — change button title temporarily
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

    // MARK: - Helpers

    private func urlEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
