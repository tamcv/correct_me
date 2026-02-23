---
id: TASK-009
title: Remove sudo symlink from build.sh — dev-only build flow
status: In Progress
assignee: []
created_date: '2026-02-23 10:46'
updated_date: '2026-02-23 10:47'
labels:
  - devex
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Current `build.sh` runs `sudo ln -sf` to create a CLI symlink at `/usr/local/bin/correctme`, which prompts for admin password every build. This is unnecessary friction for developers and irrelevant for end-users (who will use the DMG installer from TASK-006).

Changes needed:
1. Remove the `sudo ln -sf` line from `build.sh`
2. Remove the install-to-Applications flow from `build.sh` — keep it as a dev build script only
3. Dev runs app directly via `swift run` or `.build/debug/CorrectMe`
4. End-user installation will be handled by DMG installer (TASK-006)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 build.sh runs without requiring sudo or admin password
- [ ] #2 App can still be built and run by developers via swift run or .build/ binary
- [ ] #3 No changes to end-user installation path (handled by TASK-006)
<!-- AC:END -->
