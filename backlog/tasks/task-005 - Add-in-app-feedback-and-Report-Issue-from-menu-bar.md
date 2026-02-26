---
id: TASK-005
title: Add in-app feedback and Report Issue from menu bar
status: Done
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-26 09:20'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
No way for users to report bugs or request features from within the app. They must find the GitHub repo themselves.

Add "Send Feedback..." menu item in the menu bar dropdown:
- Simple window: category dropdown (Bug / Feature Request / Other) + text area + Send button
- Auto-attach: app version, macOS version, last 3 error log entries (no user text)
- Send via: open pre-filled GitHub issue URL in browser
- Also add "Copy Debug Info" button for manual paste into GitHub issues

File: Sources/MenuBarManager.swift
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Send Feedback menu item opens a feedback window
- [x] #2 Feedback pre-fills GitHub issue URL with category + version info
- [x] #3 No user correction text is ever included in the report
- [x] #4 Copy Debug Info button copies version + error log to clipboard
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added in-app feedback window accessible from the menu bar.

**New file:**
- `Sources/FeedbackWindowController.swift` — Singleton NSPanel with category dropdown (Bug/Feature/Other), description text area, auto-filled debug info (version, macOS, provider, model, last 3 errors). Two actions: "Open GitHub Issue" (builds pre-filled URL and opens browser) and "Copy Debug Info" (copies to clipboard). No user correction text is ever included.

**Modified file:**
- `Sources/MenuBarManager.swift` — Added "Send Feedback…" menu item between Preferences and Quit, with `openFeedback()` action.
<!-- SECTION:FINAL_SUMMARY:END -->
