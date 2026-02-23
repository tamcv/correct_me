---
id: TASK-001
title: Store API keys in macOS Keychain instead of plaintext config file
status: To Do
assignee: []
created_date: '2026-02-23 09:01'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
API keys currently stored in plaintext in ~/.correctme/config.json. Any app with file read access can see them.

Changes needed:
- Use Security.framework / SecKeychainItem to store API keys
- On save: write key to Keychain (kSecClassGenericPassword, service=com.correctme.app)
- On load: read key from Keychain; only store placeholder "keychain" in JSON
- Update setup wizard to mention Keychain storage
- Migrate existing plaintext keys on first launch
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 API keys are not stored in config.json
- [ ] #2 Keys are readable via Keychain and survive app restarts
- [ ] #3 Setup wizard explains Keychain storage to the user
<!-- AC:END -->
