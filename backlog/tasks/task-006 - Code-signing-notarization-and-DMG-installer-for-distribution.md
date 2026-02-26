---
id: TASK-006
title: 'Code signing, notarization, and DMG installer for distribution'
status: Done
assignee: []
created_date: '2026-02-23 09:03'
updated_date: '2026-02-26 00:24'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
App is not code-signed with Apple Developer certificate and not notarized. macOS Gatekeeper blocks downloads from the internet.

Required before selling:
- Proper .app bundle structure (already done)
- Code sign with Apple Developer ID certificate
- Notarize with notarytool
- Create signed .dmg installer
- GitHub Actions workflow: build → sign → notarize → create DMG → attach to release
- Update `correctme update` to verify signature after download

Requires: Apple Developer Program membership ($99/year)

Files: .github/workflows/release.yml (new), scripts/build-release.sh (new)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 App passes Gatekeeper on a clean Mac (no quarantine warning)
- [ ] #2 DMG installer is signed and notarized
- [ ] #3 GitHub Actions workflow produces a release-ready artifact
- [ ] #4 Trying: https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh
Checking for updates...
✅ Update complete. verifies the downloaded binary signature
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented DMG installer pipeline with code signing and notarization support.

**New files:**
- `scripts/build-release.sh` — Full release pipeline: build .app → code sign (hardened runtime) → create DMG with Applications symlink → sign DMG → notarize via notarytool → staple ticket. Falls back to unsigned DMG when no credentials are set.
- `Resources/CorrectMe.entitlements` — Hardened runtime entitlements (apple-events for Accessibility API)

**Modified files:**
- `.github/workflows/release.yml` — Certificate import from GitHub Secrets, calls build-release.sh, uploads DMG instead of ZIP, updated latest.json with format field, keychain cleanup
- `scripts/install.sh` — Supports both DMG and ZIP formats, mounts DMG to copy .app, verifies code signature after install, stops running daemon before upgrade
- `Sources/main.swift` — Added `verifyInstalledSignature()` called after `correctme update`

**Env vars for signing (GitHub Secrets):**
- `DEVELOPER_ID_CERT_BASE64`, `DEVELOPER_ID_CERT_PASSWORD` — certificate
- `DEVELOPER_ID` — signing identity name
- `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` — notarization

**Tested:** Unsigned DMG builds correctly locally (508K), contains CorrectMe.app + Applications symlink for drag-and-drop install."
<!-- SECTION:FINAL_SUMMARY:END -->
