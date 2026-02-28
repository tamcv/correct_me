---
id: TASK-017
title: Add quota usage UI and license management in Preferences
status: To Do
assignee: []
created_date: '2026-02-28 07:59'
labels:
  - correct_me
  - swift
  - ui
milestone: m-0
dependencies:
  - TASK-016
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add UI elements for users to see their quota usage and manage their license.

**Scope:** correct_me codebase (Swift)

**Components:**
- **Menu bar**: Show usage indicator for bundle key users (e.g. "15/30" or progress bar)
- **Preferences → General tab** (or new License tab):
  - Current tier display (Free / Pro / One-time / BYO)
  - License key input field + activate button
  - Usage bar: "X / Y requests used this month" with reset date
  - Upgrade button (opens purchase URL)
  - "Use my own API key instead" toggle
- **Onboarding/Setup wizard update**:
  - Add option: "Use built-in AI (free, 30 req/month)" vs "Use your own API key"
  - If bundle key chosen → auto-register as free tier

**Menu bar updates (MenuBarManager.swift):**
- For bundle key users: show quota in dropdown menu
- When quota < 20%: show warning color
- When quota = 0: show "Quota exceeded — Upgrade or add your own key"
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Menu bar shows quota usage for bundle key users
- [ ] #2 Preferences displays current tier and usage clearly
- [ ] #3 License key can be entered and activated from Preferences
- [ ] #4 Upgrade button opens correct purchase URL
- [ ] #5 Setup wizard offers bundle key vs BYO key choice
- [ ] #6 Quota warning appears when usage > 80%
- [ ] #7 BYO key users see no quota-related UI
<!-- AC:END -->
