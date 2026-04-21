# CorrectMe

> AI-powered text correction for macOS — select text, press a hotkey, done.

**[→ correctme.app landing page](https://tamcv.github.io/correct_me/)**

CorrectMe lives in your menu bar. Select any text in any app, press **⌘⇧E**, and your AI provider corrects it in place — no switching windows, no copy-pasting.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green) ![Free](https://img.shields.io/badge/price-free-brightgreen)

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
```

Or download the latest `.app` from [Releases](https://github.com/tamcv/correct_me/releases) and drag it into Applications.

After installing, grant **Accessibility** permission when prompted — this is required to read and replace selected text.

---

## How it works

1. CorrectMe runs as a menu bar app — look for the ✏️ icon
2. Select any text in **any** app
3. Press **⌘⇧E** (customizable)
4. A HUD appears near your cursor while the AI works
5. A diff preview shows what changed — press **Return** to apply or **Escape** to discard

---

## Features

- **Works in any app** — browser, Slack, Xcode, Terminal, Notes, anywhere
- **Diff preview** — see exactly what changed before applying, accept with ⌘↩ or discard with Esc
- **Multiple AI providers** — Claude, Gemini, OpenAI, OpenRouter, or local CLI tools (no API key needed)
- **Per-app writing style** — different tone for Slack vs. code comments vs. email
- **Correction history** — last 10 corrections accessible from the menu bar
- **Undo** — restore original text instantly after applying
- **Vietnamese & multilingual** — AI preserves the original language
- **Customizable hotkey** — change ⌘⇧E to anything you prefer
- **Auto-update** — notified when a new version ships
- **Privacy-first** — API keys stored in macOS Keychain, no telemetry

---

## Supported AI providers

| Provider | Type | Requires |
|----------|------|----------|
| **Ollama** | Local | [Ollama](https://ollama.com) installed and running |
| Claude Code CLI | Local | [Claude Code](https://claude.ai/code) installed |
| Codex CLI | Local | Codex CLI installed |
| GitHub Copilot CLI | Local | Copilot CLI installed |
| Claude API | Cloud | Anthropic API key |
| Google Gemini | Cloud | Gemini API key (free tier available) |
| OpenAI | Cloud | OpenAI API key |
| OpenRouter | Cloud | OpenRouter API key (100+ models, free tier available) |

**Ollama** is the recommended option for privacy — models run entirely on your machine, no data leaves your computer.

---

## Requirements

- macOS 13 Ventura or later
- One of the supported AI providers above
- Accessibility permission (prompted on first run)

---

## Quick start with Ollama (no API key needed)

```bash
# 1. Install Ollama
brew install ollama   # or download from https://ollama.com

# 2. Pull a model
ollama pull llama3.2

# 3. Configure CorrectMe
correctme quicksetup --provider ollama --model llama3.2
```

## Configuration

Open the menu bar icon → **⚙️ Preferences** to configure:

- **Provider & model** — pick your AI backend, paste your API key
- **Hotkey** — record a custom trigger shortcut
- **Writing style** — global style instructions appended to every prompt
- **Per-app styles** — override the global style for specific apps
- **Advanced** — export/import config, reset settings

---

## Build from source

```bash
git clone https://github.com/tamcv/correct_me.git
cd correct_me
swift build
.build/debug/CorrectMe start
```

To build the `.app` bundle:

```bash
./scripts/build-app.sh
```

---

## Contributing

Contributions are welcome! This project is fully open source.

- **Bug reports & feature requests** → [open an issue](https://github.com/tamcv/correct_me/issues)
- **Pull requests** → fork, branch, and submit a PR
- **New AI provider** — see `Sources/AIProviders.swift` for the protocol to implement

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/uninstall.sh | sh
```

Or drag CorrectMe.app to Trash and remove `~/.correctme/`.

---

## License

MIT — free to use, modify, and distribute.
