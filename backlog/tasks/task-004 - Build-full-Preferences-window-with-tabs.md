---
id: TASK-004
title: Build full Preferences window with tabs
status: Done
assignee: []
created_date: '2026-02-23 09:02'
updated_date: '2026-02-24 07:33'
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
- [x] #1 All settings accessible without terminal
- [x] #2 API key field is masked and has a Test button
- [x] #3 Hotkey tab allows recording a new shortcut by pressing keys
- [x] #4 Writing Style tab replaces the current standalone window
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Created `Sources/PreferencesWindowController.swift` with 5-tab NSTabView preferences window:\n\n- **General**: auto-start toggle, current hotkey display, version/provider info\n- **Provider**: dropdown for all 6 providers, masked API key field with Test Connection button, model field\n- **Hotkey**: large display of current hotkey, preset buttons, Record Custom Hotkey, Reset to Default\n- **Writing Style**: moved existing WritingStyleWindowController content (text view, presets, clear)\n- **Advanced**: config file path + Show in Finder, Export/Import config, Reset All Settings\n\nUpdated `MenuBarManager.openPreferences()` to open new Preferences window instead of standalone Writing Style window. Added `Notification.Name.configChanged` for config reload signaling."
<!-- SECTION:FINAL_SUMMARY:END -->
