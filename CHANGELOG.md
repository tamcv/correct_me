# Changelog

All notable changes to CorrectMe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Professional daemon management (start, stop, restart, status)
- Automatic stale PID file cleanup
- PID reuse detection
- Code signing in build script and installer
- Interactive setup wizard in installer
- Graceful shutdown with proper cleanup

### Fixed
- Terminal hanging on startup
- macOS Gatekeeper killing unsigned binaries
- Build script hanging during installation

### Changed
- Simplified auto-start strategy
- Improved installation UX
- Better error messages and status reporting

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Global hotkey support (⌘⇧E)
- Multiple AI providers (Claude Code, Codex, Claude API, Gemini, OpenAI)
- Multi-language support
- macOS native integration
- Background daemon mode
