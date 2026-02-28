---
id: TASK-016
title: Add license tier system and bundle key support in CorrectMe app
status: To Do
assignee: []
created_date: '2026-02-28 07:58'
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
Add licensing logic to the CorrectMe macOS app so it can work with the bundle key proxy server.

**Scope:** correct_me codebase (Swift)

**Components:**
- New `LicenseManager.swift`:
  - Store license key in Keychain (alongside existing API keys)
  - Detect tier: BYO key (user has own API key) vs bundle key (free/pro/one-time)
  - Device ID generation (hardware UUID)
  - License activation flow (call `/v1/activate`)
  - Quota check (call `/v1/quota`)
- New `BundleAIProvider` in `AIProviders.swift`:
  - Instead of calling DeepSeek directly, calls the Cloudflare Worker proxy endpoint
  - Sends `{ licenseKey, deviceId, text }` to `POST /v1/correct`
  - Handles quota exceeded error gracefully
- Update `Config.swift`:
  - Add `useBundleKey: Bool` config option
  - Add `licenseKey: String?` config option
  - Add proxy server URL constant
- Update `main.swift` / `handleHotkey()`:
  - Route through `BundleAIProvider` when `useBundleKey` is true
  - Show quota exceeded HUD message when limit reached

**Logic:**
- If user has their own API key → use existing providers (no change)
- If user chooses bundle key → use BundleAIProvider → proxy server
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
