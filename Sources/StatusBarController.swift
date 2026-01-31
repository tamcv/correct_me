import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let spinner: NSProgressIndicator
    private let button: NSStatusBarButton

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 52)
        guard let button = statusItem.button else {
            fatalError("Failed to create status bar button")
        }
        self.button = button

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        button.title = "CM"
        button.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4)
        ])

        statusItem.menu = makeMenu()
    }

    func setBusy() {
        button.title = "CM"
        spinner.startAnimation(nil)
    }

    func setIdle() {
        button.title = "CM"
        spinner.stopAnimation(nil)
    }

    func setError() {
        button.title = "!"
        spinner.stopAnimation(nil)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit CorrectMe", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
