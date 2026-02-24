---
id: TASK-004
title: Build full Preferences window with tabs
status: In Progress
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-24 07:29'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Current "Preferences" in menu bar only opens the Writing Style window. Users cannot change provider, API key, or hotkey without using the terminal.

Build an NSWindowController with NSTabView:
- General tab: auto-start toggle, HUD timeout, language hints
- Providers tab: list all providers, enable/disable, API key field (masked), "Test" button, model picker
- Hotkey tab: interactive key recorder widget
- Writing Style tab: move existing WritingStyleWindowController content here
- Advanced tab: verbose logging toggle, config file path, export/import config

Files: Sources/PreferencesWindowController.swift (new), Sources/MenuBarManager.swift
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All settings accessible without terminal
- [ ] #2 API key field is masked and has a Test button
- [ ] #3 Hotkey tab allows recording a new shortcut by pressing keys
- [ ] #4 Writing Style tab replaces the current standalone window
<!-- AC:END -->
