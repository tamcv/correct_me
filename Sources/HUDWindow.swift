import AppKit
import Foundation

/// A small HUD window that appears near the mouse cursor to show correction status.
/// Uses NSVisualEffectView for a modern vibrancy/blur appearance matching macOS Sequoia.
class HUDWindow: NSWindow {
    private let hudView: HUDView
    private var autoHideTimer: Timer?

    init() {
        hudView = HUDView()

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 110, height: 76),
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

    /// Store cached selection bounds
    private var cachedSelectionBounds: NSRect?

    /// Cache the current selection bounds (call this before showing loading)
    func cacheSelectionBounds() {
        cachedSelectionBounds = AccessibilityHelper.getSelectedTextBounds()
    }

    /// Show the HUD near the selected text (or mouse cursor as fallback) with a loading state
    func showLoading() {
        positionNearSelection()
        hudView.setState(.loading)
        orderFrontRegardless()
        cancelAutoHide()
        StatusManager.shared.setStatus(.processing)
    }

    /// Show success state and auto-hide after delay
    func showSuccess() {
        hudView.setState(.success)
        scheduleAutoHide(after: 0.8)
        StatusManager.shared.setStatus(.success)
    }

    /// Show error state and auto-hide after delay
    func showError() {
        hudView.setState(.error)
        scheduleAutoHide(after: 1.5)
        StatusManager.shared.setStatus(.error)
    }

    /// Hide the HUD immediately
    func hide() {
        cancelAutoHide()
        orderOut(nil)
    }

    private func positionNearSelection() {
        if let bounds = cachedSelectionBounds {
            cachedSelectionBounds = nil
            positionNearBounds(bounds)
        } else {
            positionNearMouse()
        }
    }

    private func screen(containing point: CGPoint) -> NSScreen {
        return NSScreen.screens.first(where: { $0.frame.contains(point) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen()
    }

    private func positionNearBounds(_ bounds: NSRect) {
        let selectionMid = CGPoint(x: bounds.midX, y: bounds.midY)
        let screenFrame = screen(containing: selectionMid).frame

        var hudOrigin = CGPoint(
            x: bounds.origin.x,
            y: bounds.origin.y - frame.height - 8
        )

        if hudOrigin.y < screenFrame.minY + 10 {
            hudOrigin.y = bounds.origin.y + bounds.height + 8
        }

        if hudOrigin.x + frame.width > screenFrame.maxX - 10 {
            hudOrigin.x = screenFrame.maxX - frame.width - 10
        }
        if hudOrigin.x < screenFrame.minX + 10 {
            hudOrigin.x = screenFrame.minX + 10
        }

        if hudOrigin.y + frame.height > screenFrame.maxY - 10 {
            hudOrigin.y = screenFrame.maxY - frame.height - 10
        }

        setFrameOrigin(hudOrigin)
    }

    private func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen(containing: mouseLocation).frame

        var hudOrigin = CGPoint(
            x: mouseLocation.x + 8,
            y: mouseLocation.y - frame.height - 8
        )

        if hudOrigin.y < screenFrame.minY + 10 {
            hudOrigin.y = mouseLocation.y + 8
        }

        if hudOrigin.x + frame.width > screenFrame.maxX - 10 {
            hudOrigin.x = mouseLocation.x - frame.width - 8
        }
        if hudOrigin.x < screenFrame.minX + 10 {
            hudOrigin.x = screenFrame.minX + 10
        }

        if hudOrigin.y + frame.height > screenFrame.maxY - 10 {
            hudOrigin.y = screenFrame.maxY - frame.height - 10
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

private class HUDView: NSVisualEffectView {
    enum HUDState {
        case loading
        case success
        case error
    }

    private var hudState: HUDState = .loading
    private let spinner = NSProgressIndicator()
    private let iconView = NSImageView()
    private let textLabel = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Vibrancy / blur effect
        material = .hudWindow
        blendingMode = .behindWindow
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        // Spinner
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // SF Symbol icon view
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isHidden = true
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        // Text label
        textLabel.isBezeled = false
        textLabel.drawsBackground = false
        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.alignment = .center
        textLabel.font = .systemFont(ofSize: 11, weight: .medium)
        textLabel.textColor = .labelColor
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.maximumNumberOfLines = 2
        textLabel.lineBreakMode = .byWordWrapping
        addSubview(textLabel)

        // Layout
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            textLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6)
        ])
    }

    func setState(_ newState: HUDState) {
        hudState = newState

        switch hudState {
        case .loading:
            spinner.isHidden = false
            spinner.startAnimation(nil)
            iconView.isHidden = true
            textLabel.stringValue = "Correcting…"
            textLabel.textColor = .labelColor

        case .success:
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            iconView.isHidden = false
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
                iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")?
                    .withSymbolConfiguration(config)
                iconView.contentTintColor = .systemGreen
            } else {
                iconView.isHidden = true
            }
            textLabel.stringValue = "Done"
            textLabel.textColor = .systemGreen

        case .error:
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            iconView.isHidden = false
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
                iconView.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Error")?
                    .withSymbolConfiguration(config)
                iconView.contentTintColor = .systemRed
            } else {
                iconView.isHidden = true
            }
            textLabel.stringValue = "Error"
            textLabel.textColor = .systemRed
        }
    }
}
