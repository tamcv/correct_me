---
id: TASK-014
title: Setup Cloudflare Worker as AI proxy + auth server
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
updated_date: '2026-02-28 08:12'
labels:
  - cloudflare
  - backend
  - infra
milestone: m-0
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a Cloudflare Worker that acts as both an auth/quota gateway and AI proxy to DeepSeek API.

**Scope:** New Cloudflare project (NOT correct_me codebase)

**Components:**
- Cloudflare Worker with KV bindings
- KV namespaces: `LICENSES` (license key → tier info), `USAGE` (license key → monthly count)
- Endpoint: `POST /v1/correct` — receives license key + text, validates, counts, forwards to DeepSeek
- Endpoint: `GET /v1/quota` — returns current usage and remaining quota for a license key
- Endpoint: `POST /v1/activate` — verify license key is valid (no device binding)
- Rate limiting and error handling
- Cron trigger for monthly usage reset (calendar month in UTC)

**Auth flow:**
1. App sends `{ licenseKey, deviceId, text }` to Worker
2. Worker validates license in KV → check tier → check quota (per license key, NOT per device)
3. If valid: forward to DeepSeek, increment usage count, return response
4. If invalid/exceeded: return appropriate error code

**Device policy:**
- Multi-device allowed — no device limit per license
- Quota is tracked per license key, not per device
- Device ID is sent for analytics/debugging only, NOT for enforcement
- One license key can be used on unlimited Macs simultaneously

**Pricing model & tiers:**
- `free`: Bundle key 30 req/month (BYO key = 7-day trial, handled client-side)
- `one-time` ($9-15): BYO key unlimited (no proxy needed), Bundle key 30 req/month
- `pro` ($3-5/mo subscription): Bundle key 1000 req/month
- `lifetime` ($29-49 one-time): Bundle key 1000 req/month, perpetual

**Quota limits enforced by Worker (per license key):**
- free + one-time: 30 req/month
- pro + lifetime: 1000 req/month
- BYO key users don't hit this server at all

**Quota reset policy:**
- Reset by calendar month (UTC), not rolling 30 days
- `/v1/quota` must include `resetAt` so client can show exact reset time
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Worker deploys and responds to health check
- [ ] #2 POST /v1/correct validates license and proxies to DeepSeek successfully
- [ ] #3 Usage counting increments correctly per license key (not per device)
- [ ] #4 Returns 429 when quota exceeded with clear error message
- [ ] #5 GET /v1/quota returns accurate usage info for a license key, including `resetAt` (UTC)
- [ ] #6 POST /v1/activate verifies license key is valid (no device binding)
- [ ] #7 Monthly cron resets usage counters using calendar month UTC
- [ ] #8 DeepSeek API key is never exposed to client
- [ ] #9 Same license key works from multiple devices simultaneously
<!-- AC:END -->
