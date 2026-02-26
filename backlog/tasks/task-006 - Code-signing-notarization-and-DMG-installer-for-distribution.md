---
id: TASK-006
title: 'Code signing, notarization, and DMG installer for distribution'
status: In Progress
assignee: []
created_date: '2026-02-23 09:03'
updated_date: '2026-02-26 00:19'
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
