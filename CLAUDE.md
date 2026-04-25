# CorrectMe — macOS Menu Bar Text Correction App

## Overview
macOS menu bar app (Swift, SPM, macOS 13+) that corrects selected text using AI on a global hotkey. Runs as a background daemon with an `NSStatusItem`.

Current version: **0.3.3**

## Architecture

```
Sources/
├── main.swift                       # Entry point, CLI dispatcher, handleHotkey()
├── Config.swift                     # User config → ~/.correctme/config.json
├── AIProviders.swift                # AIProvider protocol + implementations
├── HotkeyManager.swift              # CGEvent tap for global hotkey
├── AccessibilityHelper.swift        # Get/replace selected text via AX API
├── HUDWindow.swift                  # Floating status window (spinner → ✓/✗)
├── MenuBarManager.swift             # NSStatusItem, dropdown menu
├── PreferencesWindowController.swift # Preferences window (tabs)
├── QuickActionPickerWindow.swift    # Floating action picker panel
├── DaemonManager.swift              # PID file, launchctl, SIGTERM
└── ErrorLog.swift                   # Thread-safe error log + StatusManager
```

## Build & Run

```bash
swift build              # debug build → .build/debug/CorrectMe
swift test               # run tests
swift run CorrectMe start
swift run CorrectMe status
```

**Deploy for testing:**
```bash
cp .build/debug/CorrectMe .build/CorrectMe.app/Contents/MacOS/correctme
sh scripts/deploy.sh     # copies to /Applications/CorrectMe.app and restarts
```

## Coding Standards

- No force unwrap (`!`) — use `guard`/`if let`/`Result`
- Thread safety: `DispatchQueue` for shared state (see `ErrorLog.swift`)
- Propagate errors, log to `ErrorLog` with appropriate category
- No hardcoded strings — use constants or enums
- Comments in English; one responsibility per file

## UI Guidelines

- Menu bar icon: pencil (✏️) with status dot — gray/yellow/green/red
- HUD: borderless floating, auto-hides 0.8s (success) / 1.5s (error)
- Dark mode: no hardcoded colors — use `NSColor.labelColor` etc.
- Menu bar Preferences item: `"⚙️  Preferences..."` (two spaces after emoji)

## Roadmap

All planned items complete. Next features TBD.

## Autonomous Agent Instructions

1. Read this file for context
2. `swift build` — fix compile errors first
3. `swift test` — fix failures (known: `testCheckAccessibilityPermissionsReturnsBool` always fails — ignore it)
4. Pick highest-priority unchecked roadmap item, implement it
5. Build + test again, mark done, commit (`feat:` / `fix:` / `test:`)

**Safety Rules:** Never modify `~/.correctme/config.json`. Never commit API keys. Always build successfully before committing.

## Key File Details

**New AI provider:** Add enum case in `Config.swift`, implement protocol in `AIProviders.swift`, add to `createAIProvider(from:)` factory.

**Menu changes:** `MenuBarManager.swift` → `buildMenu()`.

**HUD states:** `.loading` / `.success` / `.error` — called from `main.swift` → `handleHotkey()`.

**Config changes:** Add `Codable` property to `Config` struct, add to `CodingKeys`, set default in `init()`.

**Version bump:** `./scripts/bump-version.sh X.Y.Z` — updates `VERSION`, `Sources/Version.swift`, `Resources/Info.plist`.

## Dependencies

No third-party packages — pure Apple frameworks (CoreGraphics, AppKit, Accessibility).

<!-- BACKLOG.MD MCP GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->
