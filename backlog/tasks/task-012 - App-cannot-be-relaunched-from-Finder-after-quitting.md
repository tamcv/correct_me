---
id: TASK-012
title: App cannot be relaunched from Finder after quitting
status: To Do
assignee: []
created_date: '2026-02-25 08:09'
labels:
  - bug
  - ux
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

After clicking "Quit CorrectMe" in the menu bar, there is no way to restart the app without using the terminal (`correctme start`). Double-clicking CorrectMe.app in /Applications does nothing useful — it runs with no arguments, calls `printHelp()`, and exits.

Additionally, the current "Quit" behavior is confusing: launchd's `KeepAlive.SuccessfulExit=false` causes the daemon to auto-restart immediately after quitting, so the user clicks Quit but the app comes back.

## Root Cause

1. **main.swift entry point** (line ~68): When launched with no CLI arguments (e.g. double-click from Finder), it prints help and exits instead of starting the daemon.
2. **LaunchAgent plist** (`KeepAlive.SuccessfulExit=false`): launchd restarts the process whenever it exits, making "Quit" ineffective.

## Proposed Solution

### Fix 1: Support Finder launch (double-click)
In `main.swift`, detect when launched with no arguments (or via Finder/LaunchServices) and auto-start the daemon instead of showing help:

```swift
// If no args and running from Finder (not terminal), start daemon directly
if CommandLine.arguments.count == 1 {
    // Check if already running
    if DaemonManager.isRunning {
        // Bring existing instance to front or just exit
        exit(0)
    }
    // Start daemon directly (same as __daemon_start)
    DaemonManager.writePID(getpid())
    DaemonManager.setupCleanupHandlers()
    runDaemon()
}
```

### Fix 2: Fix Quit behavior
Change "Quit CorrectMe" to properly stop the daemon via launchctl:

In `MenuBarManager.swift`, change `quitApp()`:
```swift
@objc private func quitApp() {
    // Unload from launchctl so it doesn't auto-restart
    DaemonManager.stopViaLaunchctl()
    NSApplication.shared.terminate(nil)
}
```

Or alternatively, use a different exit code that `KeepAlive.SuccessfulExit` recognizes as intentional (exit code 0 = successful exit, launchd won't restart).

### Fix 3: Verify SIGTERM handler exit code
In `DaemonManager.swift`, the SIGTERM handler calls `exit(0)`. Since plist has `KeepAlive.SuccessfulExit=false`, exit(0) means "successful exit" → launchd should NOT restart. But `NSApplication.shared.terminate()` may use a different exit path. Verify this.

## Key Files
- `Sources/main.swift` — CLI dispatcher, entry point (lines 49-68)
- `Sources/MenuBarManager.swift` — `quitApp()` (line 402)
- `Sources/DaemonManager.swift` — LaunchAgent plist generation, signal handlers
- `Resources/Info.plist` — LSUIElement=true (menu bar app)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Double-clicking CorrectMe.app in /Applications starts the daemon correctly
- [ ] #2 Clicking Quit CorrectMe in menu bar actually quits and does NOT auto-restart
- [ ] #3 Running `correctme start` from terminal still works as before
- [ ] #4 App auto-starts at login if auto-start is enabled in Preferences
- [ ] #5 If app is already running and user double-clicks .app again it does not launch a second instance
<!-- AC:END -->
