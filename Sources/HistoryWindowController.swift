import Cocoa

// MARK: - HistoryWindowController
//
// Uses frame-based (autoresizingMask) layout — same pattern as
// PreferencesWindowController which is proven to work in our
// menu-bar daemon context.

final class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()

    private var window: NSPanel?
    private var tableView: NSTableView!
    private var entries: [CorrectionEntry] = []
    private var countLabel: NSTextField!

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyUpdated),
            name: .correctionHistoryUpdated,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    func showWindow() {
        if let existing = window {
            reloadData()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindow()
        reloadData()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Build UI (frame-based)

    private func buildWindow() {
        let w: CGFloat = 640
        let h: CGFloat = 420
        let bottomBarH: CGFloat = 40

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Correction History"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 480, height: 300)
        panel.level = .floating
        panel.hidesOnDeactivate = false

        guard let contentView = panel.contentView else { return }
        let bounds = contentView.bounds

        // ── Bottom bar ─────────────────────────────────────────
        let bottomBar = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bottomBarH))
        bottomBar.autoresizingMask = [.width]
        contentView.addSubview(bottomBar)

        let clearBtn = NSButton(title: "Clear All", target: self, action: #selector(clearAll))
        clearBtn.bezelStyle = .rounded
        clearBtn.controlSize = .small
        clearBtn.sizeToFit()
        clearBtn.frame.origin = NSPoint(x: 12, y: (bottomBarH - clearBtn.frame.height) / 2)
        clearBtn.autoresizingMask = [.maxXMargin]
        bottomBar.addSubview(clearBtn)

        let copyBtn = NSButton(title: "Copy Corrected", target: self, action: #selector(copySelected))
        copyBtn.bezelStyle = .rounded
        copyBtn.controlSize = .small
        copyBtn.sizeToFit()
        copyBtn.frame.origin = NSPoint(x: clearBtn.frame.maxX + 8, y: clearBtn.frame.origin.y)
        copyBtn.autoresizingMask = [.maxXMargin]
        bottomBar.addSubview(copyBtn)

        let lbl = NSTextField(labelWithString: "")
        lbl.font = .systemFont(ofSize: 11)
        lbl.textColor = .secondaryLabelColor
        lbl.alignment = .right
        lbl.frame = NSRect(x: bounds.width - 160, y: (bottomBarH - 16) / 2, width: 148, height: 16)
        lbl.autoresizingMask = [.minXMargin]
        bottomBar.addSubview(lbl)
        self.countLabel = lbl

        // ── Separator ──────────────────────────────────────────
        let sep = NSBox(frame: NSRect(x: 0, y: bottomBarH, width: bounds.width, height: 1))
        sep.boxType = .separator
        sep.autoresizingMask = [.width]
        contentView.addSubview(sep)

        // ── Table ──────────────────────────────────────────────
        let tableY = bottomBarH + 1
        let tableH = bounds.height - tableY

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: tableY, width: bounds.width, height: tableH))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        contentView.addSubview(scrollView)

        let tv = NSTableView(frame: scrollView.bounds)
        tv.style = .inset
        tv.rowSizeStyle = .medium
        tv.usesAlternatingRowBackgroundColors = true
        tv.allowsMultipleSelection = false
        tv.doubleAction = #selector(copySelected)
        tv.target = self
        tv.delegate = self
        tv.dataSource = self

        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = "Time"
        timeCol.width = 80
        timeCol.minWidth = 60
        timeCol.maxWidth = 120

        let origCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("original"))
        origCol.title = "Original"
        origCol.width = 240
        origCol.minWidth = 100
        origCol.resizingMask = [.userResizingMask, .autoresizingMask]

        let corrCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("corrected"))
        corrCol.title = "Corrected"
        corrCol.width = 240
        corrCol.minWidth = 100
        corrCol.resizingMask = [.userResizingMask, .autoresizingMask]

        tv.addTableColumn(timeCol)
        tv.addTableColumn(origCol)
        tv.addTableColumn(corrCol)

        scrollView.documentView = tv
        self.tableView = tv

        self.window = panel
    }

    // MARK: - Data

    private func reloadData() {
        entries = CorrectionHistory.shared.getEntries()
        tableView?.reloadData()
        let count = entries.count
        countLabel?.stringValue = count == 0 ? "No entries" : "\(count) correction\(count == 1 ? "" : "s")"
    }

    @objc private func historyUpdated() {
        guard let win = window, win.isVisible else { return }
        DispatchQueue.main.async { self.reloadData() }
    }

    // MARK: - Actions

    @objc private func clearAll() {
        guard !entries.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Clear History"
        alert.informativeText = "Are you sure you want to delete all \(entries.count) correction\(entries.count == 1 ? "" : "s")?"
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let win = window else { return }
        alert.beginSheetModal(for: win) { [weak self] response in
            if response == .alertFirstButtonReturn {
                CorrectionHistory.shared.clear()
                self?.reloadData()
            }
        }
    }

    @objc private func copySelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entries[row].correctedText, forType: .string)

        // Brief visual feedback
        let oldTitle = window?.title ?? "Correction History"
        window?.title = "✓ Copied to clipboard!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.window?.title = oldTitle
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Keep the window around for reuse
    }
}

// MARK: - NSTableViewDataSource

extension HistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }
}

// MARK: - NSTableViewDelegate

extension HistoryWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < entries.count else { return nil }
        let entry = entries[row]
        let colId = tableColumn?.identifier.rawValue ?? ""

        let cellId = NSUserInterfaceItemIdentifier("hist-\(colId)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let tf = NSTextField(labelWithString: "")
            tf.lineBreakMode = .byTruncatingTail
            tf.maximumNumberOfLines = 1
            tf.frame = cell.bounds
            tf.autoresizingMask = [.width, .height]
            cell.addSubview(tf)
            cell.textField = tf
        }

        switch colId {
        case "time":
            cell.textField?.stringValue = entry.timeAgo
            cell.textField?.textColor = .secondaryLabelColor
            cell.textField?.font = .systemFont(ofSize: 11)
        case "original":
            cell.textField?.stringValue = entry.originalText.replacingOccurrences(of: "\n", with: " ")
            cell.textField?.textColor = .labelColor
            cell.textField?.font = .systemFont(ofSize: 12)
        case "corrected":
            cell.textField?.stringValue = entry.correctedText.replacingOccurrences(of: "\n", with: " ")
            cell.textField?.textColor = .systemGreen
            cell.textField?.font = .systemFont(ofSize: 12)
        default:
            break
        }

        return cell
    }
}
