---
id: TASK-008
title: Add privacy policy and data handling disclosure in-app
status: To Do
assignee: []
created_date: '2026-02-23 09:03'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Users need to know what data is sent where. Required for GDPR/CCPA compliance and user trust.

Actions:
- Add "Privacy & Data" item in menu bar (under Preferences or new About window)
- Display: which provider receives text, whether corrections are logged, data retention
- Show data handling summary during first-launch onboarding (requires acknowledgment)
- Link to a Privacy Policy webpage
- Example text: "Your text is sent to [Provider] API only. CorrectMe does not store or log your corrections."

File: Sources/MenuBarManager.swift (About/Privacy menu item)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Privacy info is accessible from the menu bar without opening a browser
- [ ] #2 Onboarding includes a data handling summary step
- [ ] #3 Privacy Policy URL is linked from within the app
<!-- AC:END -->
