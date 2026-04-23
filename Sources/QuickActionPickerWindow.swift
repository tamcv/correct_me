import Cocoa

/// Floating quick-action picker that appears when the hotkey fires.
/// User picks an action (correct, translate, formal, casual, summarize, expand)
/// via mouse click or keyboard shortcut (1–6, arrows + Enter, ESC to cancel).
class QuickActionPickerWindow: NSPanel {

    static let shared = QuickActionPickerWindow()

    var onAction: ((TextAction) -> Void)?
    var onCancel: (() -> Void)?

    private var selectedIndex = 0
    private var rowViews: [NSView] = []
    private var keyMonitor: Any?

    private let rowH: CGFloat   = 40
    private let winW: CGFloat   = 238
    private let vPad: CGFloat   = 6

    // MARK: - Init

    private init() {
        let h = CGFloat(TextAction.allCases.count) * 40 + 12
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 238, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque            = false
        backgroundColor     = .clear
        hasShadow           = true
        level               = .floating
        isReleasedWhenClosed = false
        collectionBehavior  = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior   = .utilityWindow
    }

    // MARK: - Show / Dismiss

    func show(onAction: @escaping (TextAction) -> Void, onCancel: @escaping () -> Void) {
        self.onAction = onAction
        self.onCancel = onCancel
        selectedIndex = 0

        buildUI()
        updateHighlight()
        positionNearMouse()

        // Activate so keyboard events reach this window
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
    }

    func dismiss(cancelled: Bool = false) {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        orderOut(nil)
        if cancelled { onCancel?() }
    }

    // MARK: - UI

    private func buildUI() {
        let actions = TextAction.allCases
        let H = rowH * CGFloat(actions.count) + vPad * 2

        setContentSize(NSSize(width: winW, height: H))

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: winW, height: H))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(white: 0.11, alpha: 0.97).cgColor
        bg.layer?.cornerRadius    = 10
        bg.layer?.masksToBounds   = true
        contentView = bg

        rowViews.removeAll()

        for (i, action) in actions.enumerated() {
            let y   = H - vPad - rowH * CGFloat(i + 1)
            let row = makeRow(action: action, index: i, y: y)
            bg.addSubview(row)
            rowViews.append(row)
        }
    }

    private func makeRow(action: TextAction, index: Int, y: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 6, y: y, width: winW - 12, height: rowH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 6

        // Number badge
        let numLbl = NSTextField(labelWithString: action.shortcutKey)
        numLbl.font      = .monospacedSystemFont(ofSize: 10, weight: .regular)
        numLbl.textColor = NSColor(white: 0.4, alpha: 1)
        numLbl.frame     = NSRect(x: 8, y: (rowH - 14) / 2, width: 12, height: 14)
        container.addSubview(numLbl)

        // Icon
        let iconLbl  = NSTextField(labelWithString: action.icon)
        iconLbl.font = .systemFont(ofSize: 15)
        iconLbl.frame = NSRect(x: 26, y: (rowH - 20) / 2, width: 22, height: 20)
        container.addSubview(iconLbl)

        // Title
        let titleLbl      = NSTextField(labelWithString: action.title)
        titleLbl.font      = .systemFont(ofSize: 13)
        titleLbl.textColor = NSColor(white: 0.88, alpha: 1)
        titleLbl.frame     = NSRect(x: 52, y: (rowH - 16) / 2, width: winW - 68, height: 16)
        container.addSubview(titleLbl)

        // Invisible click button (covers whole row)
        let btn           = NSButton(frame: NSRect(x: 0, y: 0, width: winW - 12, height: rowH))
        btn.bezelStyle    = .shadowlessSquare
        btn.isBordered    = false
        btn.title         = ""
        btn.tag           = index
        btn.target        = self
        btn.action        = #selector(rowClicked(_:))
        container.addSubview(btn)

        // Hover tracking
        let ta = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: winW - 12, height: rowH),
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: ["index": index]
        )
        container.addTrackingArea(ta)

        return container
    }

    @objc private func rowClicked(_ sender: NSButton) {
        selectAction(at: sender.tag)
    }

    override func mouseEntered(with event: NSEvent) {
        if let idx = event.trackingArea?.userInfo?["index"] as? Int {
            selectedIndex = idx
            updateHighlight()
        }
    }

    private func updateHighlight() {
        for (i, row) in rowViews.enumerated() {
            row.layer?.backgroundColor = i == selectedIndex
                ? NSColor.controlAccentColor.withAlphaComponent(0.28).cgColor
                : NSColor.clear.cgColor
        }
    }

    // MARK: - Keyboard

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let count = TextAction.allCases.count
        switch event.keyCode {
        case 53: // ESC
            dismiss(cancelled: true)
            return nil
        case 125: // Arrow down
            selectedIndex = (selectedIndex + 1) % count
            updateHighlight()
            return nil
        case 126: // Arrow up
            selectedIndex = (selectedIndex - 1 + count) % count
            updateHighlight()
            return nil
        case 36, 76: // Return / Enter
            selectAction(at: selectedIndex)
            return nil
        default:
            if let c = event.characters, let n = Int(c), n >= 1, n <= count {
                selectAction(at: n - 1)
                return nil
            }
            return event
        }
    }

    private func selectAction(at index: Int) {
        let actions = TextAction.allCases
        guard index < actions.count else { return }
        let action  = actions[index]
        let handler = onAction
        dismiss()
        handler?(action)
    }

    // MARK: - Positioning

    private func positionNearMouse() {
        let mouse  = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let sf     = screen.frame

        // Try to the right of the cursor, vertically centred
        var origin = CGPoint(
            x: mouse.x + 14,
            y: mouse.y - frame.height / 2
        )

        // Clamp to screen
        if origin.y + frame.height > sf.maxY - 10 { origin.y = sf.maxY - frame.height - 10 }
        if origin.y < sf.minY + 10                { origin.y = sf.minY + 10 }
        if origin.x + frame.width > sf.maxX - 10  { origin.x = mouse.x - frame.width - 14 }
        if origin.x < sf.minX + 10                { origin.x = sf.minX + 10 }

        setFrameOrigin(origin)
    }
}
