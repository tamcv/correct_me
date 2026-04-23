import Cocoa

// MARK: - Picker action (standard TextAction + dynamic per-app correction)

/// What the user picked from the Quick Action Picker.
enum PickerAction {
    /// One of the 6 built-in actions (correct, translate, formal, casual, summarize, expand).
    case standard(TextAction)
    /// Correct grammar while applying the current app's custom writing style.
    case correctWithAppStyle(appName: String, style: String)
}

// MARK: - Quick Action Picker window

/// Floating panel that appears when the hotkey fires.
/// Shows 6 built-in actions + an optional "Correct · AppName" row when
/// the front-most app has a per-app writing style configured.
class QuickActionPickerWindow: NSPanel {

    static let shared = QuickActionPickerWindow()

    var onAction: ((PickerAction) -> Void)?
    var onCancel: (() -> Void)?

    private var selectedIndex = 0
    private var rowViews: [NSView] = []
    private var rowActions: [PickerAction] = []   // parallel array to rowViews
    private var keyMonitor: Any?

    private let rowH:    CGFloat = 40
    private let headerH: CGFloat = 30
    private let winW:    CGFloat = 238
    private let vPad:    CGFloat = 6

    // MARK: - Init

    private init() {
        // Placeholder size — resized properly in buildUI()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 238, height: 300),
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

    func show(
        sourceApp: NSRunningApplication?,
        onAction: @escaping (PickerAction) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onAction = onAction
        self.onCancel = onCancel
        selectedIndex = 0

        buildUI(sourceApp: sourceApp)
        updateHighlight()
        positionNearMouse()

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

    private func buildUI(sourceApp: NSRunningApplication?) {
        rowViews.removeAll()
        rowActions.removeAll()

        // ── Build item list ──
        // Standard actions + optional per-app correct row after "correct"
        var items: [(action: PickerAction, icon: String, appIcon: NSImage?,
                     title: String, badge: String?, number: String?)] = []

        let cfg = Config.load()
        for action in TextAction.allCases {
            items.append((
                action: .standard(action),
                icon: action.icon,
                appIcon: nil,
                title: action.title,
                badge: nil,
                number: action.shortcutKey
            ))

            // After "correct": inject per-app style row if available
            if action == .correct,
               let bundleId = sourceApp?.bundleIdentifier,
               let appStyle = cfg.perAppStyles?[bundleId], !appStyle.isEmpty,
               let appName = sourceApp?.localizedName {
                items.append((
                    action: .correctWithAppStyle(appName: appName, style: appStyle),
                    icon: "",            // will use appIcon instead
                    appIcon: sourceApp?.icon,
                    title: "Correct · \(appName)",
                    badge: "App style",
                    number: nil
                ))
            }
        }

        let totalRows = items.count
        let H = rowH * CGFloat(totalRows) + headerH + vPad * 2
        setContentSize(NSSize(width: winW, height: H))

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: winW, height: H))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(white: 0.11, alpha: 0.97).cgColor
        bg.layer?.cornerRadius    = 10
        bg.layer?.masksToBounds   = true
        contentView = bg

        // ── Header ──
        let titleLbl = NSTextField(labelWithString: "Quick Actions")
        titleLbl.font      = .systemFont(ofSize: 11, weight: .medium)
        titleLbl.textColor = NSColor(white: 0.45, alpha: 1)
        titleLbl.frame     = NSRect(x: 12, y: H - headerH + (headerH - 14) / 2,
                                    width: winW - 36, height: 14)
        bg.addSubview(titleLbl)

        let closeBtn = NSButton(frame: NSRect(x: winW - 26,
                                              y: H - headerH + (headerH - 18) / 2,
                                              width: 18, height: 18))
        closeBtn.bezelStyle       = .shadowlessSquare
        closeBtn.isBordered       = false
        closeBtn.title            = "✕"
        closeBtn.font             = .systemFont(ofSize: 11)
        closeBtn.contentTintColor = NSColor(white: 0.45, alpha: 1)
        closeBtn.target           = self
        closeBtn.action           = #selector(closeBtnClicked)
        bg.addSubview(closeBtn)

        let sep = NSView(frame: NSRect(x: 8, y: H - headerH, width: winW - 16, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.07).cgColor
        bg.addSubview(sep)

        // ── Action rows ──
        for (i, item) in items.enumerated() {
            let y   = H - headerH - vPad - rowH * CGFloat(i + 1)
            let row = makeRow(item: item, index: i, y: y)
            bg.addSubview(row)
            rowViews.append(row)
            rowActions.append(item.action)
        }
    }

    private func makeRow(
        item: (action: PickerAction, icon: String, appIcon: NSImage?,
               title: String, badge: String?, number: String?),
        index: Int,
        y: CGFloat
    ) -> NSView {
        let isAppStyle = item.badge != nil
        let container = NSView(frame: NSRect(x: 6, y: y, width: winW - 12, height: rowH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 6

        // Number badge (standard rows only)
        if let num = item.number {
            let numLbl = NSTextField(labelWithString: num)
            numLbl.font      = .monospacedSystemFont(ofSize: 10, weight: .regular)
            numLbl.textColor = NSColor(white: 0.4, alpha: 1)
            numLbl.frame     = NSRect(x: 8, y: (rowH - 14) / 2, width: 12, height: 14)
            container.addSubview(numLbl)
        }

        // Icon: app icon (16×16) or emoji label
        if let appIcon = item.appIcon {
            let iv = NSImageView(frame: NSRect(x: 26, y: (rowH - 16) / 2, width: 16, height: 16))
            iv.image = appIcon
            iv.imageScaling = .scaleProportionallyUpOrDown
            container.addSubview(iv)
        } else {
            let iconLbl = NSTextField(labelWithString: item.icon)
            iconLbl.font  = .systemFont(ofSize: 15)
            iconLbl.frame = NSRect(x: 26, y: (rowH - 20) / 2, width: 22, height: 20)
            container.addSubview(iconLbl)
        }

        // Title
        let badgeW: CGFloat = isAppStyle ? 62 : 0
        let titleLbl      = NSTextField(labelWithString: item.title)
        titleLbl.font      = .systemFont(ofSize: 13, weight: isAppStyle ? .regular : .regular)
        titleLbl.textColor = isAppStyle
            ? NSColor(white: 0.70, alpha: 1)   // slightly dimmer for sub-action
            : NSColor(white: 0.88, alpha: 1)
        let titleX: CGFloat = 52
        titleLbl.frame = NSRect(x: titleX, y: (rowH - 16) / 2,
                                width: winW - 12 - titleX - badgeW - 6, height: 16)
        container.addSubview(titleLbl)

        // Badge pill (app-style rows only)
        if let badge = item.badge {
            let pillW: CGFloat = badgeW
            let pillH: CGFloat = 16
            let pillX = winW - 12 - pillW - 4
            let pillY = (rowH - pillH) / 2

            let pill = NSView(frame: NSRect(x: pillX, y: pillY, width: pillW, height: pillH))
            pill.wantsLayer = true
            pill.layer?.cornerRadius = pillH / 2
            pill.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            container.addSubview(pill)

            let pillLbl = NSTextField(labelWithString: badge)
            pillLbl.font      = .systemFont(ofSize: 9, weight: .medium)
            pillLbl.textColor = .controlAccentColor
            pillLbl.alignment = .center
            pillLbl.frame     = NSRect(x: 0, y: 1, width: pillW, height: pillH - 2)
            pill.addSubview(pillLbl)
        }

        // Invisible click target
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: winW - 12, height: rowH))
        btn.bezelStyle  = .shadowlessSquare
        btn.isBordered  = false
        btn.title       = ""
        btn.tag         = index
        btn.target      = self
        btn.action      = #selector(rowClicked(_:))
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

    @objc private func closeBtnClicked() {
        dismiss(cancelled: true)
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
        let count = rowViews.count
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
            // Number shortcuts 1–6 map to TextAction positions
            if let c = event.characters, let n = Int(c), n >= 1, n <= TextAction.allCases.count {
                // Find the nth standard action row
                var stdCount = 0
                for (i, action) in rowActions.enumerated() {
                    if case .standard = action {
                        stdCount += 1
                        if stdCount == n {
                            selectAction(at: i)
                            return nil
                        }
                    }
                }
            }
            return event
        }
    }

    private func selectAction(at index: Int) {
        guard index < rowActions.count else { return }
        let pickerAction = rowActions[index]
        let handler = onAction
        dismiss()
        handler?(pickerAction)
    }

    // MARK: - Positioning

    private func positionNearMouse() {
        let mouse  = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let sf     = screen.visibleFrame   // respects Dock + menu bar
        let margin: CGFloat = 8
        let ph = frame.height
        let pw = frame.width

        var ox = mouse.x + 14
        var oy = mouse.y - 20   // slight offset so first row is near cursor

        if oy < sf.minY + margin         { oy = sf.minY + margin }
        if oy + ph > sf.maxY - margin    { oy = sf.maxY - ph - margin }
        if ox + pw > sf.maxX - margin    { ox = mouse.x - pw - 14 }
        if ox < sf.minX + margin         { ox = sf.minX + margin }

        setFrameOrigin(CGPoint(x: ox, y: oy))
    }
}
