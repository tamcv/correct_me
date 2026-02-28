---
id: TASK-010
title: Limit menu bar history to 5 items with "View All" link to history file
status: Done
assignee: []
created_date: '2026-02-24 08:32'
updated_date: '2026-02-28 10:20'
labels:
  - ui
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently the menu bar dropdown shows up to 10 correction history entries, which makes the menu too long.

Changes needed:
1. Limit history display in menu bar to 5 most recent items
2. Add a "View All History…" menu item that opens the full history file in the default text editor
3. Persist correction history to a file (e.g. ~/.correctme/history.json) so users can review past corrections
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Menu bar dropdown shows max 5 latest history entries
- [ ] #2 "View All History…" menu item opens history file in default editor
- [ ] #3 History is persisted to ~/.correctme/history.json
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Menu bar history limited to 5 items. Added "View All History…" link that opens ~/.correctme/history.json in default editor. CorrectionEntry made Codable, history persisted to disk with ISO 8601 dates. Internal max raised to 50 entries.
<!-- SECTION:FINAL_SUMMARY:END -->
