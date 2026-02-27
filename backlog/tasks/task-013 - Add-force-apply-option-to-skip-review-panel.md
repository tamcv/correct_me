---
id: TASK-013
title: Add force-apply option to skip review panel
status: Done
assignee: []
created_date: '2026-02-27 04:09'
updated_date: '2026-02-27 04:24'
labels:
  - feature
  - ui
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a "Force Apply" mode that skips the Review Correction panel and applies corrections immediately. This should be configurable in Preferences (General tab) and also accessible as a quick toggle from the Review Correction window itself.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Preference toggle in General tab to enable/disable force-apply mode
- [x] #2 When enabled, corrections are applied immediately without showing Review panel
- [x] #3 Review Correction window has a checkbox/button to enable force-apply for future corrections
- [x] #4 Config persists forceApply setting in config.json
- [x] #5 Hotkey still works the same, just skips the review step
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `forceApply` config option. When enabled, corrections skip the Review Correction panel and apply immediately. Toggle available in Preferences > General tab and as "Always apply without review" checkbox in the review window itself. 4 files changed, 43 insertions.
<!-- SECTION:FINAL_SUMMARY:END -->
