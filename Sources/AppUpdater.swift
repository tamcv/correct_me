import Sparkle
import AppKit

/// Wraps SPUStandardUpdaterController to manage Sparkle auto-updates.
/// Lifecycle: created once at app startup, held strongly (e.g. in MenuBarManager).
final class AppUpdater: NSObject, SPUUpdaterDelegate {
    static let shared = AppUpdater()

    private var updaterController: SPUStandardUpdaterController?

    private override init() {
        super.init()
        // SPUStandardUpdaterController reads SUFeedURL from Info.plist.
        // Automatic update checks are enabled by default; configure via
        // SUEnableAutomaticChecks / SUScheduledCheckInterval in Info.plist.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    /// Show the "Check for Updates…" panel programmatically (called from menu).
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        debugLog("Sparkle: will install update \(item.displayVersionString)")
    }
}
