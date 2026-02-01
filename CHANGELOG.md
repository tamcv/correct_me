# Changelog

All notable changes to CorrectMe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
