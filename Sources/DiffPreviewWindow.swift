import AppKit

/// A floating panel that shows the original and corrected text side-by-side,
/// letting the user accept or reject the AI correction before it is applied.
class DiffPreviewWindow: NSObject, NSWindowDelegate {
    static let shared = DiffPreviewWindow()

    private var panel: NSPanel?

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

        // Dismiss any existing panel first
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

    /// Close the panel without triggering onReject (used during accept/reject actions).
    private func dismissSilently() {
        let p = panel
        panel = nil
        p?.close()
    }

    // MARK: - Button actions

    @objc private func acceptPressed() {
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
        // The X button was used — treat as reject if panel reference is still live
        guard panel != nil else { return }
        panel = nil
        let reject = onReject
        onAccept = nil
        onReject = nil
        reject?()
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

        // ── Original label
        let origLabel = makeLabel("Original:", bold: true)
        origLabel.frame = NSRect(x: pad, y: H - pad - labelH, width: W - pad * 2, height: labelH)
        origLabel.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(origLabel)

        // ── Original scroll view
        let origY = H - pad - labelH - vGap - scrollH
        let origScroll = makeScrollView(frame: NSRect(x: pad, y: origY, width: W - pad * 2, height: scrollH))
        makeTextView(in: origScroll, text: original, textColor: .labelColor)
        root.addSubview(origScroll)

        // ── Corrected label
        let corrLabelY = origY - vGap * 2 - labelH
        let corrLabel = makeLabel("Corrected:", bold: true)
        corrLabel.frame = NSRect(x: pad, y: corrLabelY, width: W - pad * 2, height: labelH)
        corrLabel.textColor = NSColor(calibratedRed: 0.1, green: 0.65, blue: 0.2, alpha: 1.0)
        corrLabel.autoresizingMask = [.width, .maxYMargin]
        root.addSubview(corrLabel)

        // ── Corrected scroll view
        let corrScrollY = corrLabelY - vGap - scrollH
        let corrScroll = makeScrollView(frame: NSRect(x: pad, y: corrScrollY, width: W - pad * 2, height: scrollH))
        makeTextView(in: corrScroll, text: corrected, textColor: .labelColor)
        root.addSubview(corrScroll)

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
    private func makeTextView(in scrollView: NSScrollView, text: String, textColor: NSColor) -> NSTextView {
        let tv = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        tv.string = text
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = .systemFont(ofSize: 12)
        tv.textColor = textColor
        tv.backgroundColor = .textBackgroundColor
        tv.autoresizingMask = [.width]
        scrollView.documentView = tv
        return tv
    }
}
