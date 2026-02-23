---
id: TASK-007
title: Remove debug print statements and clean up logging
status: To Do
assignee: []
created_date: '2026-02-23 09:03'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Multiple print("[DEBUG]...") statements exist in production code (e.g. MenuBarManager.swift lines 24, 29, 32, etc.). These are signs of unfinished code and can leak information.

Actions:
- Audit all Swift source files for bare print() calls
- Replace with debugLog() (prints only when --verbose is set) or ErrorLog.shared.add()
- Ensure no user text or API keys appear in any log output
- Use a single logging pattern throughout the codebase

Files: Sources/*.swift (all)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 No print() calls remain in production code paths
- [ ] #2 All logging goes through debugLog() or ErrorLog.shared
- [ ] #3 No sensitive data (API keys, user text) in any log output
<!-- AC:END -->
