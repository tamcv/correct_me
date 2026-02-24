---
id: TASK-002
title: Per-app writing style — different style config per app
status: Done
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-24 15:37'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Users need different correction styles depending on the active app:
- Slack: casual, emoji OK
- Mail.app: formal, professional
- Xcode: technical, concise
- Notion/Obsidian: structured, markdown-aware

Changes needed:
- Add perAppStyles: [String: String] to Config (key = bundle ID)
- Detect frontmost app bundle ID in handleHotkey() before calling AI
- Pass correct writing style based on active app (fallback to global style)
- Add per-app style UI in Writing Style window (list of app overrides + add/remove)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Frontmost app bundle ID is detected before each correction
- [ ] #2 Per-app style overrides global style when set
- [ ] #3 UI allows adding/removing per-app styles from Writing Style window
- [ ] #4 Falls back to global style when no per-app override exists
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented per-app writing styles allowing different correction styles per application.

**Changes:**
- `Config.swift`: Added `perAppStyles: [String: String]?` field (bundle ID → writing style)
- `AIProviders.swift`: Added `currentCorrectionBundleId` global, modified `buildCorrectionPrompt()` to resolve per-app style with fallback to global
- `main.swift`: Set `currentCorrectionBundleId` from frontmost app in `handleHotkey()`
- `PreferencesWindowController.swift`: Added per-app styles UI section to Writing Style tab with Add App/Remove functionality, scrollable list, running apps picker
- `CLAUDE.md`: Marked roadmap item done
<!-- SECTION:FINAL_SUMMARY:END -->
