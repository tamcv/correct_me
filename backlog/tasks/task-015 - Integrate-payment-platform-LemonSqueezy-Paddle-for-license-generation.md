---
id: TASK-015
title: Integrate payment platform (LemonSqueezy/Paddle) for license generation
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
updated_date: '2026-02-28 08:12'
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

**Products to configure (LemonSqueezy or Paddle):**
1. **One-time App Purchase** ($9-15) — unlocks BYO key unlimited forever, bundle key stays at 30 req/month
2. **Pro Subscription** ($3-5/month) — bundle key 1000 req/month
3. **Lifetime Pro** ($29-49 one-time) — bundle key 1000 req/month forever
4. **Free tier** — no purchase needed, auto-assigned on first use

**Webhook endpoint on Cloudflare Worker: `POST /webhooks/payment`**
- On one-time purchase: generate license key with tier `one-time`, store in KV
- On Pro subscription purchase: generate license key with tier `pro`, store in KV
- On Lifetime Pro purchase: generate license key with tier `lifetime`, store in KV
- On subscription cancel: downgrade `pro` → `free` tier (keep license key, reduce quota)
- On subscription renew: keep `pro` tier active
- License key format: `CM-XXXX-XXXX-XXXX`

**Device policy:**
- License key is not bound to any device
- User can use the same license key on multiple Macs
- No device activation/deactivation needed

**Note:** BYO key users who buy one-time app purchase only need app activation — they don't use bundle key at all. Their license just unlocks the app past the 7-day trial.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Payment platform products configured (Pro subscription + One-time)
- [ ] #2 Webhook receives purchase events and creates license in KV
- [ ] #3 Webhook handles subscription cancellation (downgrade to free)
- [ ] #4 License keys are generated in user-friendly format
- [ ] #5 Webhook signature verification prevents spoofing
<!-- AC:END -->
