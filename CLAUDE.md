# CorrectMe — macOS Menu Bar Text Correction App

## Overview
CorrectMe is a macOS menu bar app (Swift, SPM, macOS 13+) that corrects selected text
using AI when the user triggers a global hotkey. It runs as a background daemon with a
menu bar status item.

Current version: **0.3.3**

---

## Architecture

```
Sources/
├── main.swift              # Entry point, CLI dispatcher, setup wizard, handleHotkey()
├── Config.swift            # User config (API keys, hotkey, model, style) → ~/.correctme/config.json
├── AIProviders.swift       # AIProvider protocol + 6 implementations (Claude, Gemini, OpenAI, etc.)
├── HotkeyManager.swift     # CGEvent tap — listens for global hotkey, fires correction callback
├── AccessibilityHelper.swift # Get/replace selected text via Accessibility API + CGEvent
├── HUDWindow.swift         # Floating status window (spinner → ✓ / ✗) near selected text
├── MenuBarManager.swift    # NSStatusItem, dropdown menu, WritingStyleWindowController
├── DaemonManager.swift     # PID file, launchctl, SIGTERM handler, status/uptime
└── ErrorLog.swift          # Thread-safe in-memory error log + AppStatus/StatusManager
```

---

## Build & Run

```bash
# Build
swift build

# Run (daemon mode)
swift run CorrectMe start

# Run specific subcommand
swift run CorrectMe status
swift run CorrectMe setup

# Tests
swift test
```

**Binary location after build:** `.build/debug/CorrectMe`

---

## Coding Standards

- Swift idiomatic code — no force unwrap (`!`), use `guard`/`if let`/`Result`
- Thread safety: use `DispatchQueue` for shared state (see `ErrorLog.swift` as reference)
- Error handling: propagate errors properly, log to `ErrorLog` with appropriate category
- Comments in English
- Avoid hardcoded strings — use constants or enums
- Follow existing file structure — one responsibility per file

---

## UI Guidelines (Menu Bar App)

- Menu bar icon: pencil (✏️) with status indicator dot
- Status indicator colors: gray (idle), yellow (processing), green (success), red (error)
- HUD window: borderless, floating, auto-hides after 2s on success/error
- Dropdown menu shows: current status, last correction time, recent errors (max 5)
- Dark mode must work — no hardcoded colors, use `NSColor.labelColor` etc.
- Follow macOS HIG for menu bar apps

---

## Roadmap (Priority Order)

> Agent: pick the highest unchecked item, implement it, mark as done, commit, then move to next.

### Bugs
- [x] Clipboard fallback (Cmd+C) sometimes pastes old clipboard content — add delay or restore clipboard after correction
- [x] HUD window occasionally appears on wrong screen in multi-monitor setup
- [x] Daemon sometimes doesn't detect when AI provider CLI is missing — show clearer error

### Features
- [x] Show diff/preview of correction before applying (accept/reject with keyboard shortcut)
- [ ] Correction history — last 10 corrections accessible from menu bar
- [ ] Per-app writing style — different style config for different apps (e.g. Slack vs Xcode)
- [ ] Keyboard shortcut to undo last correction (restore original text)
- [ ] Status bar shows provider name and model currently in use
- [ ] Support Vietnamese language correction (add to prompt builder)

### Quality
- [ ] Add tests for `AccessibilityHelper` text get/replace flow
- [ ] Add tests for `AIProviders` prompt building with different styles
- [ ] Add tests for `ErrorLog` thread safety
- [ ] Add tests for `Config` load/save round-trip

### DevEx
- [ ] Add `--verbose` flag for debug logging to stderr
- [ ] `correctme doctor` command — checks all dependencies (API key, accessibility perms, hotkey)

---

## Autonomous Agent Instructions

When running in autonomous mode, follow this loop:

1. **Read this file** for context
2. **Build** with `swift build` — fix any compile errors before proceeding
3. **Run tests** with `swift test` — fix any failures
4. **Pick the highest priority unchecked item** from Roadmap above
5. **Implement** the feature/fix:
   - Keep changes minimal and focused
   - Follow Coding Standards above
   - Add/update tests if applicable
6. **Build again** to verify no new errors (`swift build`)
7. **Run tests** again (`swift test`)
8. **Mark item as done** in this file (change `- [ ]` to `- [x]`)
9. **Commit** with a clear message: `feat: ...` / `fix: ...` / `test: ...`
10. **Repeat** from step 4

### Safety Rules
- Never modify `~/.correctme/config.json` (user data)
- Never run `swift run CorrectMe uninstall`
- Never commit API keys or secrets
- If a task seems too risky or complex (>200 lines changed), skip it and document why in commit message
- Always `swift build` successfully before committing

---

## Key File Details

### Adding a new AI provider
1. Add case to `AIProvider` enum in `Config.swift`
2. Implement `AIProvider` protocol in `AIProviders.swift`
3. Add to `createAIProvider(from:)` factory
4. Add model constant if needed

### Modifying the menu bar menu
- Edit `MenuBarManager.swift` → `buildMenu()` function
- Use `NSMenuItem` with `action` selectors

### Modifying the HUD
- Edit `HUDWindow.swift`
- Three states: `.loading`, `.success(String)`, `.error(String)`
- Called from `main.swift` → `handleHotkey()`

### Config changes
- Add property to `Config` struct in `Config.swift`
- Must be `Codable` — add to `CodingKeys` if needed
- Set sensible default in `init()`

---

## Dependencies
- **No third-party packages** — pure Apple frameworks only
- CoreGraphics (CGEvent tap)
- AppKit (NSStatusItem, NSWindow, NSMenu)
- Accessibility (AXUIElement)
