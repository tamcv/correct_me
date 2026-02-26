---
id: TASK-011
title: 'Fix: Clear History should not close the menu bar dropdown'
status: Done
assignee: []
created_date: '2026-02-24 08:36'
updated_date: '2026-02-26 00:07'
labels:
  - bug
  - ui
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When clicking "Clear History" in the menu bar dropdown, the menu closes immediately. Expected behavior: the menu stays open and refreshes to show the history section cleared.

Root cause: NSMenu closes automatically when any menu item action is triggered. Need to keep the menu open after clearing history, or re-open it after the clear action.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Clicking Clear History does not close the menu bar dropdown
- [x] #2 History section updates in-place to show empty state after clearing
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a 50ms async re-open of the status bar menu after `clearHistory()` fires. Since NSMenu auto-closes on any item action, calling `statusItem?.button?.performClick(nil)` after the clear lets the notification cycle (queue.async → main.async) complete so the rebuilt menu shows the empty history state.
<!-- SECTION:FINAL_SUMMARY:END -->
