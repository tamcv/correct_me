---
id: TASK-017
title: Add quota usage UI and license management in Preferences
status: To Do
assignee: []
created_date: '2026-02-28 07:59'
updated_date: '2026-02-28 08:12'
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
Add UI elements for users to see their quota usage, manage license, and choose between BYO key and bundle key.

**Scope:** correct_me codebase (Swift)

**Components:**
- **Menu bar**: Show usage indicator for bundle key users (e.g. "15/30" or progress bar)
- **Preferences → new License tab**:
  - Current tier display (Free / One-time / Pro / Lifetime / BYO)
  - License key input field + activate button (just validates key, no device binding)
  - For bundle key users: usage bar "X / Y requests used this month" with reset date
  - Note: quota is shared across all devices using this license
  - For BYO free users: "Trial: X days remaining"
  - Upgrade button (opens purchase URL) — context-aware:
    - Free BYO → "Buy app ($9-15)" or "Try bundle key"
    - Free bundle → "Upgrade to Pro ($3-5/mo)" or "Buy Lifetime ($29-49)"
    - One-time bundle → "Upgrade to Pro" or "Buy Lifetime"
  - "Use my own API key instead" toggle
- **Onboarding/Setup wizard update**:
  - Add choice: "Use built-in AI (free, 30 req/month)" vs "Use your own API key (free 7-day trial)"
  - If bundle key chosen → auto-register as free tier
  - If BYO key chosen → start 7-day trial timer

**Menu bar updates (MenuBarManager.swift):**
- For bundle key users: show quota in dropdown menu
- When quota remaining < 20%: show warning color
- When quota = 0: show "Quota exceeded — Upgrade or add your own key"
- For BYO trial users: show "Trial: X days left" in menu

**Device policy note:**
- No device management UI needed — license key simply works on any Mac
- Quota display reflects shared usage across all user's devices
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
