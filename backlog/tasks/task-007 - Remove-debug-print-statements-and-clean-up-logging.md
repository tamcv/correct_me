---
id: TASK-007
title: Remove debug print statements and clean up logging
status: Done
assignee: []
created_date: '2026-02-23 09:03'
updated_date: '2026-02-28 10:20'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced all 13 debug print() calls across MenuBarManager.swift, DaemonManager.swift, and HotkeyManager.swift with debugLog() (verbose-only) or ErrorLog.shared.log() (for actual errors). CLI user-facing print() calls kept as-is.
<!-- SECTION:FINAL_SUMMARY:END -->
