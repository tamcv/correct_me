---
id: TASK-021
title: 'Support operations: in-app license self-serve and incident response playbook'
status: To Do
assignee: []
created_date: '2026-03-02 00:08'
labels:
  - support
  - ops
  - monetization
  - m-0
dependencies:
  - TASK-017
  - TASK-019
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
To sell sustainably, support overhead must stay low and incidents must be recoverable.

Scope:
- Add self-serve actions in app: re-check license, restore purchase, copy diagnostic bundle id/license state.
- Create support macros/templates for common billing issues.
- Add structured error codes for activation/quota/payment states shown to users.
- Document incident playbook (payment outage, worker outage, webhook delay).
- Add status page link or fallback messaging in app when backend degraded.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Users can self-serve restore/revalidate license without manual intervention
- [ ] #2 Activation/quota/payment errors show actionable messages + error codes
- [ ] #3 Support playbook exists with owner, escalation path, and recovery steps
- [ ] #4 Common billing tickets can be resolved using templates in < 10 minutes
- [ ] #5 App shows degraded-service message when backend health check fails
<!-- AC:END -->
