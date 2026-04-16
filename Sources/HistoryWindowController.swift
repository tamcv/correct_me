import Cocoa

// MARK: - HistoryWindowController

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
        NSApp.activate(ignoringOtherApps: true)
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        buildWindow()
        reloadData()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Build UI

    private func buildWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Correction History"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 480, height: 300)

        // Use the panel's own contentView — do NOT replace it; replacing with a
        // translatesAutoresizingMaskIntoConstraints=false view leaves it frameless.
        guard let root = panel.contentView else { return }

        // ── Table ──────────────────────────────────────────────
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        root.addSubview(scrollView)

        let tv = NSTableView()
        tv.usesAutomaticRowHeights = true
        tv.style = .inset
        tv.rowSizeStyle = .medium
        tv.gridStyleMask = .solidHorizontalGridLineMask
        tv.gridColor = NSColor.separatorColor
        tv.selectionHighlightStyle = .regular
        tv.allowsMultipleSelection = false
        tv.doubleAction = #selector(copySelected)
        tv.target = self
        tv.delegate = self
        tv.dataSource = self

        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = "Time"
        timeCol.width = 80
        timeCol.minWidth = 60
        timeCol.maxWidth = 100
        timeCol.resizingMask = .userResizingMask

        let origCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("original"))
        origCol.title = "Original"
        origCol.minWidth = 120
        origCol.resizingMask = [.userResizingMask, .autoresizingMask]

        let corrCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("corrected"))
        corrCol.title = "Corrected"
        corrCol.minWidth = 120
        corrCol.resizingMask = [.userResizingMask, .autoresizingMask]

        tv.addTableColumn(timeCol)
        tv.addTableColumn(origCol)
        tv.addTableColumn(corrCol)
        tv.sizeLastColumnToFit()

        scrollView.documentView = tv
        self.tableView = tv

        // ── Bottom bar ─────────────────────────────────────────
        let divider = NSBox()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.boxType = .separator
        root.addSubview(divider)

        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bottomBar)

        let clearBtn = NSButton(title: "Clear All", target: self, action: #selector(clearAll))
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.bezelStyle = .rounded
        clearBtn.controlSize = .small
        bottomBar.addSubview(clearBtn)

        let copyBtn = NSButton(title: "Copy Corrected", target: self, action: #selector(copySelected))
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        copyBtn.bezelStyle = .rounded
        copyBtn.controlSize = .small
        bottomBar.addSubview(copyBtn)

        let lbl = NSTextField(labelWithString: "")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 11)
        lbl.textColor = .secondaryLabelColor
        lbl.alignment = .right
        bottomBar.addSubview(lbl)
        self.countLabel = lbl

        let hint = NSTextField(labelWithString: "Double-click a row to copy corrected text")
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        bottomBar.addSubview(hint)

        // ── Constraints ────────────────────────────────────────
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: divider.topAnchor),

            divider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bottomBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44),

            clearBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            clearBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            copyBtn.leadingAnchor.constraint(equalTo: clearBtn.trailingAnchor, constant: 8),
            copyBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            hint.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            lbl.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            lbl.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        self.window = panel
    }

    // MARK: - Data

    private func reloadData() {
        entries = CorrectionHistory.shared.getEntries()
        tableView?.reloadData()
        countLabel?.stringValue = entries.isEmpty ? "No entries" : "\(entries.count) correction\(entries.count == 1 ? "" : "s")"
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
        let oldTitle = window?.title ?? ""
        window?.title = "✓ Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.window?.title = oldTitle
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // nothing
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
        let id = tableColumn?.identifier.rawValue ?? ""

        let cellId = NSUserInterfaceItemIdentifier("cell-\(id)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            tf.maximumNumberOfLines = 1
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        switch id {
        case "time":
            cell.textField?.stringValue = entry.timeAgo
            cell.textField?.textColor = .secondaryLabelColor
            cell.textField?.font = .systemFont(ofSize: 11)
            cell.textField?.alignment = .left
        case "original":
            cell.textField?.stringValue = entry.originalText.replacingOccurrences(of: "\n", with: " ")
            cell.textField?.textColor = .labelColor
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.alignment = .left
        case "corrected":
            cell.textField?.stringValue = entry.correctedText.replacingOccurrences(of: "\n", with: " ")
            cell.textField?.textColor = NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.alignment = .left
        default:
            break
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // nothing — copy is on double-click
    }
}
