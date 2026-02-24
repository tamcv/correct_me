---
id: TASK-011
title: 'Fix: Clear History should not close the menu bar dropdown'
status: To Do
assignee: []
created_date: '2026-02-24 08:36'
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
- [ ] #1 Clicking Clear History does not close the menu bar dropdown
- [ ] #2 History section updates in-place to show empty state after clearing
<!-- AC:END -->
