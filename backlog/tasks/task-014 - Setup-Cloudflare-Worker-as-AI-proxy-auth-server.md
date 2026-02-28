---
id: TASK-014
title: Setup Cloudflare Worker as AI proxy + auth server
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
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
- KV namespaces: `LICENSES` (license key → tier/device info), `USAGE` (device → monthly count)
- Endpoint: `POST /v1/correct` — receives license key + text, validates, counts, forwards to DeepSeek
- Endpoint: `GET /v1/quota` — returns current usage and remaining quota for a license key
- Endpoint: `POST /v1/activate` — activate a license key on a device
- Rate limiting and error handling
- Cron trigger for monthly usage reset

**Auth flow:**
1. App sends `{ licenseKey, deviceId, text }` to Worker
2. Worker validates license in KV → check tier → check quota
3. If valid: forward to DeepSeek, increment usage count, return response
4. If invalid/exceeded: return appropriate error code

**Tiers & quotas:**
- `free`: 30 req/month
- `pro`: 1000 req/month (subscription)
- `one-time`: 1000 req/month (perpetual)
- No bundle key (BYO): not handled by this server
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Worker deploys and responds to health check
- [ ] #2 POST /v1/correct validates license and proxies to DeepSeek successfully
- [ ] #3 Usage counting increments correctly per request
- [ ] #4 Returns 429 when quota exceeded with clear error message
- [ ] #5 GET /v1/quota returns accurate usage info
- [ ] #6 POST /v1/activate links license key to device
- [ ] #7 Monthly cron resets usage counters
- [ ] #8 DeepSeek API key is never exposed to client
<!-- AC:END -->
