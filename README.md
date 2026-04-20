# CorrectMe

> AI-powered text correction for macOS — select text, press a hotkey, done.

CorrectMe lives in your menu bar. Select any text in any app, press **⌘⇧E**, and your AI provider corrects it in place. No switching windows, no copy-pasting.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
```

Or download the DMG from [Releases](https://github.com/tamcv/correct_me/releases) and drag **CorrectMe.app** into Applications.

After installing, grant **Accessibility** permissions when prompted (required to read and replace selected text).

---

## How it works

1. CorrectMe runs as a menu bar app — pencil icon (✏️) in the top-right corner
2. Select text in **any** app
3. Press **⌘⇧E** (customizable)
4. A small HUD appears near your cursor while the AI works
5. Your text is replaced with the corrected version

Supports a diff preview before applying — accept with **Return**, reject with **Escape**.

---

## Features

- **Works everywhere** — any app that supports text selection
- **Multiple AI providers** — Claude API, Google Gemini, OpenAI, or local CLI tools (Claude Code, Codex)
- **Diff preview** — see what changed before committing
- **Correction history** — last 10 corrections accessible from the menu
- **Per-app writing style** — different tone for Slack vs. code comments vs. email
- **Undo** — restore original text with a single shortcut
- **Vietnamese & multilingual** — preserves the original language
- **Auto-update** — Sparkle-based, notified when a new version ships
- **Privacy-first** — your API keys stay local in `~/.correctme/`

---

## Setup

Open the menu bar icon → **Preferences** to configure:

- **Provider & model** — pick your AI backend and model
- **Hotkey** — change the trigger shortcut
- **Writing style** — adjust tone (professional, casual, concise…)
- **Per-app styles** — override style for specific apps

Or use the setup wizard the first time you launch.

---

## Supported AI providers

| Provider | Requires |
|----------|----------|
| Claude API | Anthropic API key |
| Google Gemini | Gemini API key |
| OpenAI | OpenAI API key |
| Claude Code CLI | [Claude Code](https://claude.ai/code) installed locally |
| Codex CLI | Codex CLI installed locally |

---

## Requirements

- macOS 13 Ventura or later
- An AI provider (API key or local CLI)
- Accessibility permission (prompted on first run)

---

## Build from source

```bash
git clone https://github.com/tamcv/correct_me.git
cd correct_me
swift build
```

To build and install the `.app` bundle:

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/uninstall.sh | sh
```

Or drag CorrectMe.app to Trash and remove `~/.correctme/`.

---

## License

MIT
