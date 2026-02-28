import AppKit

/// A floating panel that shows the original and corrected text side-by-side,
/// letting the user accept or reject the AI correction before it is applied.
/// Styled to match modern macOS Sequoia design language.
class DiffPreviewWindow: NSObject, NSWindowDelegate {
    static let shared = DiffPreviewWindow()

    private var panel: NSPanel?
    private var alwaysApplyCheckbox: NSButton?

    /// Called when the user accepts the correction.
    var onAccept: (() -> Void)?
    /// Called when the user rejects (discards) the correction, or closes the window.
    var onReject: (() -> Void)?

    private override init() { super.init() }

    /// Show the preview panel with the original and corrected text.
    func show(original: String, corrected: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show(original: original, corrected: corrected) }
            return
        }

        dismissSilently()

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "Review Correction"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .visible
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.delegate = self
        p.backgroundColor = .windowBackgroundColor

        buildContent(in: p, original: original, corrected: corrected)
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = p
    }

    /// Close the panel without triggering onReject.
    private func dismissSilently() {
        let p = panel
        panel = nil
        p?.close()
    }

    // MARK: - Button actions

    @objc private func acceptPressed() {
        if alwaysApplyCheckbox?.state == .on {
            var config = Config.load()
            config.forceApply = true
            try? config.save()
        }
        dismissSilently()
        onAccept?()
        onAccept = nil
        onReject = nil
    }

    @objc private func rejectPressed() {
        dismissSilently()
        onReject?()
        onAccept = nil
        onReject = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard panel != nil else { return }
        panel = nil
        let reject = onReject
        onAccept = nil
        onReject = nil
        reject?()
    }

    // MARK: - Word-level diff (LCS-based)

    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var lastWasSpace = false
        for char in text {
            let isSpace = char.isWhitespace
            if isSpace != lastWasSpace && !current.isEmpty {
                tokens.append(current)
                current = ""
            }
            current.append(char)
            lastWasSpace = isSpace
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private struct DiffResult {
        let origAttr: NSAttributedString
        let corrAttr: NSAttributedString
        let changedWordCount: Int
    }

    private func computeDiff(original: String, corrected: String) -> DiffResult {
        let origTokens = tokenize(original)
        let corrTokens = tokenize(corrected)
        let m = origTokens.count
        let n = corrTokens.count

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        if m > 0 && n > 0 {
            for i in 1...m {
                for j in 1...n {
                    if origTokens[i - 1] == corrTokens[j - 1] {
                        dp[i][j] = dp[i - 1][j - 1] + 1
                    } else {
                        dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                    }
                }
            }
        }

        var origParts: [(text: String, deleted: Bool)] = []
        var corrParts: [(text: String, inserted: Bool)] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && origTokens[i - 1] == corrTokens[j - 1] {
                origParts.append((origTokens[i - 1], false))
                corrParts.append((corrTokens[j - 1], false))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                corrParts.append((corrTokens[j - 1], true))
                j -= 1
            } else {
                origParts.append((origTokens[i - 1], true))
                i -= 1
            }
        }
        origParts.reverse()
        corrParts.reverse()

        let isWord: (String) -> Bool = { !$0.allSatisfy(\.isWhitespace) }
        let deletedCount = origParts.filter { $0.deleted && isWord($0.text) }.count
        let insertedCount = corrParts.filter { $0.inserted && isWord($0.text) }.count
        let changedCount = max(deletedCount, insertedCount)

        let font = NSFont.systemFont(ofSize: 13)

        let origAttr = NSMutableAttributedString()
        for part in origParts {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
            if part.deleted && isWord(part.text) {
                attrs[.foregroundColor] = NSColor.systemRed
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attrs[.strikethroughColor] = NSColor.systemRed
            }
            origAttr.append(NSAttributedString(string: part.text, attributes: attrs))
        }

        let corrAttr = NSMutableAttributedString()
        for part in corrParts {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
            if part.inserted && isWord(part.text) {
                attrs[.foregroundColor] = NSColor.systemGreen
            }
            corrAttr.append(NSAttributedString(string: part.text, attributes: attrs))
        }

        return DiffResult(origAttr: origAttr, corrAttr: corrAttr, changedWordCount: changedCount)
    }

    // MARK: - UI construction

    private func buildContent(in p: NSPanel, original: String, corrected: String) {
        guard let root = p.contentView else { return }
        let W = root.bounds.width
        let H = root.bounds.height
        let pad: CGFloat = 20
        let scrollH: CGFloat = 100

        let diff = computeDiff(original: original, corrected: corrected)

        var y = H - 16

        // ── Original section
        y -= 18
        let origLabel = makeSectionLabel("Original", icon: "doc.text", color: .secondaryLabelColor)
        origLabel.frame = NSRect(x: pad, y: y, width: W - pad * 2, height: 18)
        root.addSubview(origLabel)

        y -= scrollH + 6
        let origScroll = makeScrollView(frame: NSRect(x: pad, y: y, width: W - pad * 2, height: scrollH))
        makeTextView(in: origScroll, attributedText: diff.origAttr)
        root.addSubview(origScroll)

        y -= 28

        // ── Corrected section with change count badge
        let corrLabel = makeSectionLabel("Corrected", icon: "doc.text.fill", color: .systemGreen)
        corrLabel.frame = NSRect(x: pad, y: y, width: 120, height: 18)
        root.addSubview(corrLabel)

        // Change count badge
        let countText: String
        switch diff.changedWordCount {
        case 0:  countText = "no changes"
        case 1:  countText = "1 word changed"
        default: countText = "\(diff.changedWordCount) words changed"
        }

        let badge = makeChangeBadge(countText)
        badge.frame = NSRect(x: W - pad - 130, y: y - 1, width: 130, height: 20)
        root.addSubview(badge)

        y -= scrollH + 6
        let corrScroll = makeScrollView(frame: NSRect(x: pad, y: y, width: W - pad * 2, height: scrollH))
        makeTextView(in: corrScroll, attributedText: diff.corrAttr)
        root.addSubview(corrScroll)

        // ── Bottom bar
        let bottomY: CGFloat = pad

        // "Always apply" checkbox
        let alwaysApply = NSButton(checkboxWithTitle: "Always apply without review", target: nil, action: nil)
        alwaysApply.frame = NSRect(x: pad, y: bottomY + 4, width: 250, height: 20)
        alwaysApply.font = .systemFont(ofSize: 12)
        root.addSubview(alwaysApply)
        self.alwaysApplyCheckbox = alwaysApply

        // Reject button
        let rejectBtn = NSButton(title: "Discard", target: self, action: #selector(rejectPressed))
        rejectBtn.bezelStyle = .rounded
        rejectBtn.controlSize = .large
        rejectBtn.keyEquivalent = "\u{1b}"
        rejectBtn.keyEquivalentModifierMask = []
        rejectBtn.frame = NSRect(x: W - pad - 220, y: bottomY, width: 100, height: 30)
        rejectBtn.autoresizingMask = [.minXMargin]
        root.addSubview(rejectBtn)

        // Accept button
        let acceptBtn = NSButton(title: "Apply", target: self, action: #selector(acceptPressed))
        acceptBtn.bezelStyle = .rounded
        acceptBtn.controlSize = .large
        acceptBtn.keyEquivalent = "\r"
        acceptBtn.keyEquivalentModifierMask = .command
        acceptBtn.frame = NSRect(x: W - pad - 110, y: bottomY, width: 110, height: 30)
        acceptBtn.autoresizingMask = [.minXMargin]
        root.addSubview(acceptBtn)

        // Keyboard shortcut hints
        let hintLabel = NSTextField(labelWithString: "⌘↩ Apply  ·  Esc Discard")
        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.frame = NSRect(x: W - pad - 220, y: bottomY + 34, width: 220, height: 14)
        hintLabel.autoresizingMask = [.minXMargin]
        root.addSubview(hintLabel)
    }

    // MARK: - UI Helpers

    private func makeSectionLabel(_ text: String, icon: String, color: NSColor) -> NSView {
        let container = NSView()

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let imageView = NSImageView()
                imageView.image = image
                imageView.contentTintColor = color
                imageView.frame = NSRect(x: 0, y: 1, width: 16, height: 16)
                container.addSubview(imageView)
            }
        }

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = color
        label.frame = NSRect(x: 20, y: 0, width: 200, height: 18)
        container.addSubview(label)

        return container
    }

    private func makeChangeBadge(_ text: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .controlAccentColor
        label.alignment = .center
        label.frame = NSRect(x: 4, y: 2, width: 122, height: 16)
        container.addSubview(label)

        return container
    }

    private func makeScrollView(frame: NSRect) -> NSScrollView {
        let sv = NSScrollView(frame: frame)
        sv.hasVerticalScroller = true
        sv.borderType = .bezelBorder
        sv.autoresizingMask = [.width]
        sv.scrollerStyle = .overlay
        return sv
    }

    @discardableResult
    private func makeTextView(in scrollView: NSScrollView, attributedText: NSAttributedString) -> NSTextView {
        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .textBackgroundColor
        tv.autoresizingMask = [.width]
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.textStorage?.setAttributedString(attributedText)
        scrollView.documentView = tv
        return tv
    }
}
