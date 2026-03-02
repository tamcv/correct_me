---
id: TASK-019
title: >-
  Revenue reliability: webhook idempotency, entitlement reconciliation, and
  failed-payment handling
status: To Do
assignee: []
created_date: '2026-03-02 00:08'
labels:
  - backend
  - payment
  - monetization
  - m-0
dependencies:
  - TASK-014
  - TASK-015
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Selling requires resilient billing state, not just happy-path webhook handling.

Scope:
- Implement idempotent webhook processing (dedupe by event id).
- Add retry-safe updates for license tier changes.
- Build daily reconciliation job between payment provider and LICENSES KV.
- Handle failed payment / past_due / canceled states with clear downgrade rules.
- Add admin/debug endpoint or script to inspect one license lifecycle.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Duplicate webhook events do not create duplicate licenses or incorrect tier transitions
- [ ] #2 Reconciliation job reports mismatches and can auto-heal safe cases
- [ ] #3 Past_due/canceled subscriptions transition to correct tier deterministically
- [ ] #4 Each license has auditable event trail (timestamp + source event id)
- [ ] #5 Runbook exists for manual recovery of broken entitlement
<!-- AC:END -->
