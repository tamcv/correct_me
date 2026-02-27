import AppKit

/// A floating panel that shows the original and corrected text side-by-side,
/// letting the user accept or reject the AI correction before it is applied.
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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        p.title = "Review Correction"
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.delegate = self

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
        // Save "always apply" preference if checked
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

    /// Splits text into alternating word/whitespace tokens, preserving all characters.
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
        /// Number of non-whitespace words that were added or removed.
        let changedWordCount: Int
    }

    private func computeDiff(original: String, corrected: String) -> DiffResult {
        let origTokens = tokenize(original)
        let corrTokens = tokenize(corrected)
        let m = origTokens.count
        let n = corrTokens.count

        // Build LCS DP table
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

        // Backtrack to reconstruct diff
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

        let font = NSFont.systemFont(ofSize: 12)

        // Original: deleted words in red + strikethrough
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

        // Corrected: inserted words in green
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
        let pad: CGFloat = 14
        let labelH: CGFloat = 17
        let scrollH: CGFloat = 96
        let btnH: CGFloat = 26
        let vGap: CGFloat = 6

        let diff = computeDiff(original: original, corrected: corrected)

        // ── Original label
        let origLabel = makeLabel("Original:", bold: true)
        origLabel.frame = NSRect(x: pad, y: H - pad - labelH, width: W - pad * 2, height: labelH)
        origLabel.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(origLabel)

        // ── Original scroll view
        let origY = H - pad - labelH - vGap - scrollH
        let origScroll = makeScrollView(frame: NSRect(x: pad, y: origY, width: W - pad * 2, height: scrollH))
        makeTextView(in: origScroll, attributedText: diff.origAttr)
        root.addSubview(origScroll)

        // ── Corrected label (left) + change count (right)
        let corrLabelY = origY - vGap * 2 - labelH
        let corrLabel = makeLabel("Corrected:", bold: true)
        corrLabel.frame = NSRect(x: pad, y: corrLabelY, width: 100, height: labelH)
        corrLabel.textColor = NSColor(calibratedRed: 0.1, green: 0.65, blue: 0.2, alpha: 1.0)
        corrLabel.autoresizingMask = [.maxYMargin]
        root.addSubview(corrLabel)

        let countText: String
        switch diff.changedWordCount {
        case 0:  countText = "no changes"
        case 1:  countText = "1 word changed"
        default: countText = "\(diff.changedWordCount) words changed"
        }
        let changeCountLabel = makeLabel(countText, bold: false)
        changeCountLabel.alignment = .right
        changeCountLabel.frame = NSRect(x: pad, y: corrLabelY, width: W - pad * 2, height: labelH)
        changeCountLabel.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(changeCountLabel)

        // ── Corrected scroll view
        let corrScrollY = corrLabelY - vGap - scrollH
        let corrScroll = makeScrollView(frame: NSRect(x: pad, y: corrScrollY, width: W - pad * 2, height: scrollH))
        makeTextView(in: corrScroll, attributedText: diff.corrAttr)
        root.addSubview(corrScroll)

        // ── "Always apply" checkbox
        let alwaysApply = NSButton(checkboxWithTitle: "Always apply without review", target: nil, action: nil)
        alwaysApply.frame = NSRect(x: pad, y: pad, width: 250, height: btnH)
        alwaysApply.font = .systemFont(ofSize: 11)
        alwaysApply.autoresizingMask = [.maxYMargin]
        root.addSubview(alwaysApply)
        self.alwaysApplyCheckbox = alwaysApply

        // ── Reject button (Escape)
        let rejectBtn = NSButton(title: "Discard  ⎋", target: self, action: #selector(rejectPressed))
        rejectBtn.bezelStyle = .rounded
        rejectBtn.keyEquivalent = "\u{1b}"
        rejectBtn.keyEquivalentModifierMask = []
        rejectBtn.frame = NSRect(x: W - pad - 240, y: pad, width: 110, height: btnH)
        rejectBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        root.addSubview(rejectBtn)

        // ── Accept button (⌘Return)
        let acceptBtn = NSButton(title: "Apply  ⌘↩", target: self, action: #selector(acceptPressed))
        acceptBtn.bezelStyle = .rounded
        acceptBtn.keyEquivalent = "\r"
        acceptBtn.keyEquivalentModifierMask = .command
        acceptBtn.frame = NSRect(x: W - pad - 120, y: pad, width: 120, height: btnH)
        acceptBtn.autoresizingMask = [.minXMargin, .maxYMargin]
        root.addSubview(acceptBtn)
    }

    private func makeLabel(_ text: String, bold: Bool) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = bold ? .systemFont(ofSize: 12, weight: .semibold) : .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabelColor
        return lbl
    }

    private func makeScrollView(frame: NSRect) -> NSScrollView {
        let sv = NSScrollView(frame: frame)
        sv.hasVerticalScroller = true
        sv.borderType = .bezelBorder
        sv.autoresizingMask = [.width]
        return sv
    }

    @discardableResult
    private func makeTextView(in scrollView: NSScrollView, attributedText: NSAttributedString) -> NSTextView {
        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .textBackgroundColor
        tv.autoresizingMask = [.width]
        tv.textStorage?.setAttributedString(attributedText)
        scrollView.documentView = tv
        return tv
    }
}
