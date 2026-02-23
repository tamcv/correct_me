---
id: TASK-003
title: Add onboarding flow — first-launch setup wizard with GUI
status: Done
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-23 10:27'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Current setup wizard runs only in terminal (CLI). Non-technical users abandon immediately.

Needed: NSWindow-based onboarding shown on first launch (no config file present).

Steps:
1. Welcome screen — what the app does + animated demo
2. Choose AI provider (dropdown)
3. Enter API key (secure text field) + "Test connection" button
4. Grant Accessibility permission — instructions + "Open System Settings" button
5. Choose hotkey (interactive key capture)
6. Done! + "Try it now" prompt

File: Sources/OnboardingWindowController.swift (new)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Onboarding window appears on first launch when no config exists
- [x] #2 API key can be entered and tested without using the terminal
- [x] #3 Accessibility permission step opens System Settings directly
- [x] #4 Hotkey can be set via key capture UI (no manual keyCode entry)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented in commit 6d8a6e5. Added GUI onboarding wizard (OnboardingWindowController) that appears on first launch when no config exists. Includes provider selection, API key entry with test button, accessibility permission step, and interactive hotkey capture.
<!-- SECTION:FINAL_SUMMARY:END -->
