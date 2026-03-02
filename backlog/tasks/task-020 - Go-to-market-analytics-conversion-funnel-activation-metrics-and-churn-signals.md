---
id: TASK-020
title: >-
  Go-to-market analytics: conversion funnel, activation metrics, and churn
  signals
status: To Do
assignee: []
created_date: '2026-03-02 00:08'
labels:
  - analytics
  - product
  - monetization
  - m-0
dependencies:
  - TASK-016
  - TASK-017
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After launch, we need product telemetry to know if the app can actually sell and retain users.

Scope:
- Define event taxonomy: install, onboarding_step_completed, first_correction, activate_license, paywall_view, checkout_click, purchase_success, quota_exceeded, churn_signal.
- Implement privacy-safe analytics pipeline (no raw corrected text).
- Build basic dashboard or daily report for funnel conversion.
- Add cohort split by mode: BYO vs bundle key.
- Track time-to-value (install -> first successful correction).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Core funnel events are emitted reliably with stable schema
- [ ] #2 No sensitive user text/API keys are sent in analytics payloads
- [ ] #3 Dashboard/report shows install→activation→purchase conversion
- [ ] #4 Can compare BYO vs bundle key conversion and retention
- [ ] #5 Alert threshold exists for severe drop in purchase_success rate
<!-- AC:END -->
