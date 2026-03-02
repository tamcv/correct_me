---
id: TASK-022
title: 'Pricing copy consistency audit across app, checkout, and website'
status: To Do
assignee: []
created_date: '2026-03-02 00:18'
labels:
  - monetization
  - ux
  - copy
  - m-0
dependencies:
  - TASK-015
  - TASK-016
  - TASK-017
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure pricing/tier messaging is consistent everywhere users see it, to reduce confusion and refund risk.

Scope:
- Audit copy in app (onboarding, preferences, upgrade prompts, quota warnings).
- Audit checkout/product pages (one-time, pro, lifetime, free).
- Audit website/docs/README pricing references.
- Create a single source-of-truth pricing copy table (tier, benefits, limits, wording).
- Update all surfaces to match that table, especially one-time plan wording (BYO unlocked forever, built-in quota remains 30/month).
- Add regression checklist for future pricing changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One canonical pricing copy table exists and is referenced by product + engineering
- [ ] #2 App copy and checkout copy match exactly for all tiers
- [ ] #3 One-time plan wording is unambiguous on every surface
- [ ] #4 No conflicting quota numbers appear across app/checkout/docs
- [ ] #5 Regression checklist is documented and used before release
<!-- AC:END -->
