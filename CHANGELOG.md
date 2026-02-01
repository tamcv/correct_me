# Changelog

All notable changes to CorrectMe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Cursor HUD** - Small floating window appears near mouse cursor showing real-time correction status
  - Loading spinner when processing
  - Success checkmark when done
  - Error indicator on failure
  - Auto-dismisses after completion

### Changed
- **BREAKING**: Simplified command structure for better user experience
  - `correctme start` now always runs in background and auto-enables LaunchAgent
  - Removed `-d/--daemon` flags from `start` command
  - Added `correctme enable` and `correctme disable` commands for LaunchAgent management
- **BREAKING**: Changed distribution format from standalone binary to .app bundle
  - Now installs to `/Applications/CorrectMe.app` instead of `/usr/local/bin/correctme`
  - CLI access via symlink at `/usr/local/bin/correctme`
  - Appears as "CorrectMe" in System Settings → Accessibility (much easier to add)
  - LaunchAgent now uses .app path for better system integration
- Simplified installer flow: asks to run setup and start daemon
- Updated all documentation to reflect simplified commands and .app bundle installation
- Logs now stored in `/tmp/correctme.log` and `/tmp/correctme.error.log`

### Added
- Proper macOS .app bundle with Info.plist
- LSUIElement set to true (runs as background agent, no dock icon)
- Auto-start via LaunchAgent is now automatic when running `correctme start`
- New `enable` command to manually enable auto-start at login
- New `disable` command to manually disable auto-start at login
- `scripts/build-app.sh` - Script to build the .app bundle

## [0.2.1] - 2026-02-01

### Fixed
- Fixed CI/CD build failures caused by unnecessary Swift setup step in GitHub Actions workflows

## [0.2.0] - 2026-02-01

### Added
- Professional daemon management commands: `start`, `stop`, `restart`, and `status`
- Background daemon mode with `start -d/--daemon`
- Daemon status reporting with uptime information
- PID file management with automatic stale file cleanup
- GitHub Actions workflows for CI/CD with automated releases
- Interactive setup wizard in the installer
- One-command installation via `curl | sh`
- AI-powered changelog generator scripts

### Changed
- Simplified auto-start scripts to use new daemon management commands
- Improved README with clear comparison of auto-start options
- Build script no longer auto-starts the daemon after installation
- Installer now handles code signing and setup automatically

### Fixed
- Program no longer hangs when running `correctme` without arguments
- macOS Gatekeeper no longer kills the binary (automatic code signing added)
- Build script no longer fails with "command not found" error from typo

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Global hotkey support (⌘⇧E)
- Multiple AI providers (Claude Code, Codex, Claude API, Gemini, OpenAI)
- Multi-language support
- macOS native integration
- Background daemon mode
