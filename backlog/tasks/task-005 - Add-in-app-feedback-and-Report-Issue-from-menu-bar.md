---
id: TASK-005
title: Add in-app feedback and Report Issue from menu bar
status: In Progress
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-26 00:38'
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
- [ ] #1 Send Feedback menu item opens a feedback window
- [ ] #2 Feedback pre-fills GitHub issue URL with category + version info
- [ ] #3 No user correction text is ever included in the report
- [ ] #4 Copy Debug Info button copies version + error log to clipboard
<!-- AC:END -->
