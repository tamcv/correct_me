# CorrectMe 📝

A native macOS tool that automatically corrects spelling and grammar of selected text using AI.

**Select text → Press hotkey → Text is corrected in place!**

## Features

- 🎯 **Global hotkey** - Works in any app (default: ⌘⇧E)
- 🤖 **Multiple AI providers** - Claude Code, Claude API, or Google Gemini
- 🌍 **Multi-language** - Preserves original language (Vietnamese, English, etc.)
- ⚡ **Fast** - Native Swift, minimal overhead
- 🔒 **Privacy** - Runs locally, API keys stored in `~/.correctme/`

## Requirements

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (`xcode-select --install`)
- One of:
  - [Claude Code](https://claude.ai/code) installed, or
  - Anthropic API key, or
  - Google Gemini API key

## Installation

```bash
# Clone or download the project
cd correct-me

# Build
chmod +x build.sh
./build.sh

# Follow prompts to install to /usr/local/bin
```

## Setup

### 1. Grant Accessibility Permissions

CorrectMe needs accessibility access to read selected text and simulate keyboard input.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Add **Terminal** (or iTerm, Warp, etc.)
4. Enable the toggle

### 2. Configure AI Provider

Choose one of three options:

```bash
# Option A: Claude Code (recommended if you have it)
correctme config provider claude-code

# Option B: Claude API
correctme config provider claude
correctme config claude-key sk-ant-api03-xxxxx

# Option C: Google Gemini
correctme config provider gemini
correctme config gemini-key AIzaSyxxxxx
```

### 3. Test It

```bash
correctme test
```

### 4. Run

```bash
correctme run
```

## Usage

1. **Select text** in any application
2. **Press ⌘⇧E** (or your custom hotkey)
3. **Text is replaced** with the corrected version

## Auto-start on Login

To run CorrectMe automatically when you log in:

```bash
cp com.correctme.daemon.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.correctme.daemon.plist
```

To stop auto-start:

```bash
launchctl unload ~/Library/LaunchAgents/com.correctme.daemon.plist
rm ~/Library/LaunchAgents/com.correctme.daemon.plist
```

## Commands

| Command | Description |
|---------|-------------|
| `correctme` | Run as daemon |
| `correctme run` | Run as daemon |
| `correctme config` | Show current configuration |
| `correctme config provider <name>` | Set AI provider |
| `correctme config claude-key <key>` | Set Claude API key |
| `correctme config gemini-key <key>` | Set Gemini API key |
| `correctme config hotkey` | Show hotkey configuration help |
| `correctme test` | Test AI correction |
| `correctme help` | Show help |

## Configuration

Config file location: `~/.correctme/config.json`

```json
{
  "aiProvider": "claude-code",
  "anthropicAPIKey": null,
  "geminiAPIKey": null,
  "hotkey": {
    "keyCode": 14,
    "modifiers": 1179648,
    "displayName": "⌘⇧E"
  },
  "customPrompt": null
}
```

### Custom Hotkey

Edit `~/.correctme/config.json` and change the `hotkey` section:

**Common key codes:**
- E: 14, C: 8, V: 9, S: 1, D: 2, R: 15
- 1-0: 18-29

**Modifier values (add together):**
- Command: 1048576
- Shift: 131072  
- Control: 262144
- Option: 524288

**Examples:**
- ⌘⇧E: keyCode=14, modifiers=1179648
- ⌘⌃C: keyCode=8, modifiers=1310720 (Command + Control)
- ⌥⇧R: keyCode=15, modifiers=655360 (Option + Shift)

## Troubleshooting

### "Failed to create event tap"

Accessibility permissions not granted. Go to System Settings → Privacy & Security → Accessibility and enable your terminal app.

### "No text selected"

Some apps don't expose selected text via Accessibility API. CorrectMe will try to use Cmd+C/Cmd+V as a fallback, but this may not work in all cases.

### "Command failed"

If using `claude-code` provider, make sure Claude Code is installed and the `claude` command is available in your PATH.

## How It Works

1. **Global hotkey listener** - Uses `CGEvent` tap to capture the hotkey globally
2. **Get selected text** - Uses macOS Accessibility API (`AXUIElement`) or clipboard fallback
3. **AI correction** - Sends text to AI provider with a prompt to correct spelling/grammar
4. **Replace text** - Pastes corrected text using clipboard simulation

## License

MIT

## Contributing

PRs welcome! Some ideas:
- [ ] Menu bar app with status indicator
- [ ] Support for more AI providers (Ollama, local LLMs)
- [ ] Custom prompts per app
- [ ] Undo support
- [ ] Notification on completion
