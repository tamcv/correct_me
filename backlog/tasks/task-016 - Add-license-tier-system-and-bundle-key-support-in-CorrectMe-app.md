---
id: TASK-016
title: Add license tier system and bundle key support in CorrectMe app
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
updated_date: '2026-02-28 08:12'
labels:
  - correct_me
  - swift
  - feature
milestone: m-0
dependencies:
  - TASK-014
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add licensing logic to the CorrectMe macOS app so it can work with the bundle key proxy server and handle all tiers.

**Scope:** correct_me codebase (Swift)

**Components:**
- New `LicenseManager.swift`:
  - Store license key in Keychain (alongside existing API keys)
  - Detect mode: BYO key (user has own API key) vs bundle key (free/pro/lifetime)
  - Device ID generation (hardware UUID) — for analytics only, not enforcement
  - License validation flow (call `/v1/activate` to verify key is valid)
  - Quota check (call `/v1/quota`)
  - Trial tracking for BYO free tier (7-day limit, stored locally)
- New `BundleAIProvider` in `AIProviders.swift`:
  - Instead of calling DeepSeek directly, calls the Cloudflare Worker proxy endpoint
  - Sends `{ licenseKey, deviceId, text }` to `POST /v1/correct`
  - Handles quota exceeded error gracefully
- Update `Config.swift`:
  - Add `useBundleKey: Bool` config option
  - Add `licenseKey: String?` config option
  - Add `licenseTier: LicenseTier` enum (free/oneTime/pro/lifetime)
  - Add proxy server URL constant
- Update `main.swift` / `handleHotkey()`:
  - Route through `BundleAIProvider` when `useBundleKey` is true
  - Show quota exceeded HUD message when limit reached
  - Show trial expired message for BYO free users after 7 days

**Device policy:**
- Same license key works on unlimited Macs — no device binding
- User enters license key on each Mac, quota is shared across all devices
- Device ID sent for analytics/debugging only

**Tier behavior in app:**
- **Free (no license):** BYO key = 7-day trial then locked. Bundle key = 30 req/month.
- **One-time ($9-15):** BYO key = unlimited forever. Bundle key = 30 req/month.
- **Pro ($3-5/mo):** BYO key = unlimited. Bundle key = 1000 req/month.
- **Lifetime ($29-49):** BYO key = unlimited forever. Bundle key = 1000 req/month forever.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 BundleAIProvider sends requests through proxy and returns corrections
- [ ] #2 License key stored securely in Keychain
- [ ] #3 App detects BYO vs bundle key mode correctly
- [ ] #4 Quota exceeded shows clear HUD message with upgrade hint
- [ ] #5 Existing BYO key users are completely unaffected
- [ ] #6 Device ID is stable across app restarts
<!-- AC:END -->
