---
id: TASK-002
title: Per-app writing style — different style config per app
status: In Progress
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-24 15:31'
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
