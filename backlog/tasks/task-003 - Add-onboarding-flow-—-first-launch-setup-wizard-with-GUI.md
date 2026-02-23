---
id: TASK-003
title: Add onboarding flow — first-launch setup wizard with GUI
status: To Do
assignee: []
created_date: '2026-02-23 09:02'
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
- [ ] #1 Onboarding window appears on first launch when no config exists
- [ ] #2 API key can be entered and tested without using the terminal
- [ ] #3 Accessibility permission step opens System Settings directly
- [ ] #4 Hotkey can be set via key capture UI (no manual keyCode entry)
<!-- AC:END -->
