---
id: TASK-015
title: Integrate payment platform (LemonSqueezy/Paddle) for license generation
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
labels:
  - cloudflare
  - backend
  - payment
milestone: m-0
dependencies:
  - TASK-014
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Setup payment platform to handle purchases and automatically generate license keys.

**Scope:** Payment platform config + Cloudflare Worker webhook handler

**Components:**
- LemonSqueezy (or Paddle) account setup with 3 products:
  - Pro subscription (monthly)
  - One-time purchase (lifetime)
  - Free tier (no purchase needed, auto-assigned)
- Webhook endpoint on Cloudflare Worker: `POST /webhooks/payment`
  - On purchase: generate license key, store in KV with tier info
  - On subscription cancel: downgrade to free tier
  - On subscription renew: keep pro tier active
- License key format: simple, user-friendly (e.g. `CM-XXXX-XXXX-XXXX`)

**Note:** Self-hosted key (BYO) users buy via App Store or direct — they get a basic app license but don't need a bundle license key.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Payment platform products configured (Pro subscription + One-time)
- [ ] #2 Webhook receives purchase events and creates license in KV
- [ ] #3 Webhook handles subscription cancellation (downgrade to free)
- [ ] #4 License keys are generated in user-friendly format
- [ ] #5 Webhook signature verification prevents spoofing
<!-- AC:END -->
