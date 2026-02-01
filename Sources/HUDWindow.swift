import AppKit
import Foundation

/// A small HUD window that appears near the mouse cursor to show correction status
class HUDWindow: NSWindow {
    private let hudView: HUDView
    private var autoHideTimer: Timer?

    init() {
        hudView = HUDView()

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.contentView = hudView
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .floating
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
        self.hasShadow = true
    }

    /// Show the HUD near the mouse cursor with a loading state
    func showLoading() {
        positionNearMouse()
        hudView.setState(.loading)
        orderFrontRegardless()
        cancelAutoHide()
    }

    /// Show success state and auto-hide after delay
    func showSuccess() {
        hudView.setState(.success)
        scheduleAutoHide(after: 0.8)
    }

    /// Show error state and auto-hide after delay
    func showError() {
        hudView.setState(.error)
        scheduleAutoHide(after: 1.5)
    }

    /// Hide the HUD immediately
    func hide() {
        cancelAutoHide()
        orderOut(nil)
    }

    private func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Position below and to the right of cursor
        var hudOrigin = CGPoint(
            x: mouseLocation.x + 20,
            y: mouseLocation.y - frame.height - 20
        )

        // Ensure HUD stays on screen
        if hudOrigin.x + frame.width > screenFrame.maxX {
            hudOrigin.x = mouseLocation.x - frame.width - 20
        }
        if hudOrigin.y < screenFrame.minY {
            hudOrigin.y = mouseLocation.y + 20
        }

        setFrameOrigin(hudOrigin)
    }

    private func scheduleAutoHide(after delay: TimeInterval) {
        cancelAutoHide()
        autoHideTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
}

// MARK: - HUD View

private class HUDView: NSView {
    enum State {
        case loading
        case success
        case error
    }

    private var state: State = .loading
    private let spinner = NSProgressIndicator()
    private let iconLabel = NSTextField()
    private let textLabel = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // Icon label (for success/error symbols)
        iconLabel.isBezeled = false
        iconLabel.drawsBackground = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        iconLabel.alignment = .center
        iconLabel.font = .systemFont(ofSize: 32)
        iconLabel.textColor = .white
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.isHidden = true
        addSubview(iconLabel)

        // Text label
        textLabel.isBezeled = false
        textLabel.drawsBackground = false
        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.alignment = .center
        textLabel.font = .systemFont(ofSize: 11, weight: .medium)
        textLabel.textColor = .white.withAlphaComponent(0.9)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)

        // Layout
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),

            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),

            textLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            textLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    func setState(_ newState: State) {
        state = newState

        switch state {
        case .loading:
            spinner.isHidden = false
            spinner.startAnimation(nil)
            iconLabel.isHidden = true
            textLabel.stringValue = "Correcting..."

        case .success:
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            iconLabel.isHidden = false
            iconLabel.stringValue = "✓"
            iconLabel.textColor = NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
            textLabel.stringValue = "Done!"

        case .error:
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            iconLabel.isHidden = false
            iconLabel.stringValue = "✕"
            iconLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            textLabel.stringValue = "Error"
        }
    }
}
