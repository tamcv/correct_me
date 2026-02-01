# CorrectMe 📝

An AI‑powered, macOS‑native text fixer built for developers.  
Uses **your own AI** (Claude Code, Codex, or your API keys)—CorrectMe does **not** provide AI.  
Correct any language quickly while chatting, writing docs, or reviewing PRs—just select text, press a hotkey, and keep going.

## One‑command install (GitHub Releases)

```bash
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
```

The installer will:
- Download and install the latest release
- Code sign the binary for macOS security
- Run the setup wizard (you'll choose your AI provider)
- Show you the next steps

After installation:

1. **Grant Accessibility permissions** (required):
   - System Settings → Privacy & Security → Accessibility
   - Add `/usr/local/bin/correctme` and enable it

2. **Start the daemon**:
   ```bash
   correctme start -d
   ```

3. **Test it**: Select any text and press ⌘⇧E!

### Daemon Management

```bash
# Check status (shows PID, uptime, log locations)
correctme status

# Stop daemon (graceful shutdown)
correctme stop

# Restart daemon
correctme restart
```

The daemon management is robust and handles:
- ✅ Automatic cleanup of stale PID files
- ✅ Detection of PID reuse (different process using same PID)
- ✅ Graceful shutdown with proper cleanup
- ✅ Process validation (ensures PID is actually CorrectMe)

### Auto-start Options (Optional)

You have three options to auto-start CorrectMe:

#### Option 1: LaunchAgent (Recommended)
Best for production use. Starts automatically at login, runs independently of terminal.

```bash
# Copy plist to LaunchAgents
cp com.correctme.daemon.plist ~/Library/LaunchAgents/

# Load and start
launchctl load ~/Library/LaunchAgents/com.correctme.daemon.plist

# To stop auto-start
launchctl unload ~/Library/LaunchAgents/com.correctme.daemon.plist
rm ~/Library/LaunchAgents/com.correctme.daemon.plist
```

#### Option 2: Terminal Auto-start (Simple)
Good for development. Starts when you open a new terminal.

```bash
# Download autostart script
mkdir -p ~/.correctme
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/correctme-autostart.sh \
  -o ~/.correctme/correctme-autostart.sh
chmod +x ~/.correctme/correctme-autostart.sh

# Add to shell config
echo '~/.correctme/correctme-autostart.sh' >> ~/.zshrc

# To disable
sed -i '' '/correctme-autostart.sh/d' ~/.zshrc
```

#### Option 3: Manual Start
Just run `correctme start -d` when you need it.

## Features

- 🎯 **Global hotkey** - Works in any app (default: ⌘⇧E)
- 🤖 **Multiple AI providers** - Claude Code, Codex Code, Claude API, Google Gemini, or OpenAI API
- 🌍 **Multi-language** - Preserves original language (Vietnamese, English, etc.)
- ⚡ **Fast** - Native Swift, minimal overhead
- 🔒 **Privacy** - Runs locally, API keys stored in `~/.correctme/`

## Requirements

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (`xcode-select --install`)
- One of:
  - [Claude Code](https://claude.ai/code) installed, or
  - Codex CLI installed, or
  - Anthropic API key, or
  - Google Gemini API key, or
  - OpenAI API key

## Installation (from source)

```bash
# Clone the project
git clone https://github.com/tamcv/correct_me.git
cd correct_me

# Build & install
chmod +x build.sh
./build.sh

# Follow prompts to:
# 1. Install to /usr/local/bin
# 2. Enable terminal auto-start (optional)
```

The build script will:
- Build release binary
- Install to `/usr/local/bin/correctme` with code signing
- Optionally setup auto-start via `~/.zshrc`

Note: Update the repo URL in `scripts/install.sh` if you fork this project.

### Auto-update

```bash
correctme update
```

## Setup

### 1. Grant Accessibility Permissions

CorrectMe needs accessibility access to read selected text and simulate keyboard input.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Add **/usr/local/bin/correctme** (use Cmd+Shift+G → `/usr/local/bin`)
4. Enable the toggle

### 2. Configure AI Provider

Run the interactive setup (recommended):

```bash
correctme setup
```

You’ll see available providers (CLI providers are verified before being marked ready).

```bash
# Option A: Claude Code (local CLI)
correctme config provider claude-code

# Option B: Codex Code (local CLI)
correctme config provider codex-code
correctme config model gpt-5.1-codex-mini

# Option C: Claude API
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
correctme config provider claude

# Option D: Google Gemini
export GEMINI_API_KEY=AIzaSyxxxxx
correctme config provider gemini

# Option E: OpenAI API (Codex via API)
export OPENAI_API_KEY=sk-xxxxx
correctme config provider codex
correctme config model gpt-5.1-codex-mini
```

Note: For API providers, the setup will fetch the model list and let you choose.  
For CLI providers, you can still choose a model manually (default is a cheap/fast model).

### 3. Configure Hotkey

```bash
correctme config hotkey
```

Choose a preset or press your desired hotkey.

**Note:** After changing config (hotkey, model, provider), restart the daemon:
```bash
correctme restart
```

### 4. Test It

```bash
correctme test
```

### 5. Start the Daemon

```bash
# Start in background
correctme start -d

# Or start in foreground for debugging
correctme start
```

## Usage

1. **Start the daemon**: `correctme start -d`
2. **Select text** in any application
3. **Press ⌘⇧E** (or your custom hotkey)
4. **Text is replaced** with the corrected version

## Commands

### Daemon Management

| Command | Description |
|---------|-------------|
| `correctme start` | Start daemon in foreground |
| `correctme start -d` | Start daemon in background |
| `correctme start --daemon` | Start daemon in background |
| `correctme stop` | Stop the daemon |
| `correctme restart` | Restart the daemon |
| `correctme status` | Check daemon status |

### Configuration

| Command | Description |
|---------|-------------|
| `correctme setup` | Interactive setup wizard |
| `correctme config` | Show current configuration |
| `correctme config provider <name>` | Set AI provider (claude-code, codex-code, claude, gemini, codex) |
| `correctme config claude-key <key>` | Set Claude API key |
| `correctme config gemini-key <key>` | Set Gemini API key |
| `correctme config openai-key <key>` | Set OpenAI API key |
| `correctme config model <name>` | Set model name |
| `correctme config hotkey` | Configure hotkey |

### Other

| Command | Description |
|---------|-------------|
| `correctme test` | Test AI correction with sample text |
| `correctme version` | Show version |
| `correctme update` | Update to latest release |
| `correctme help` | Show help message |

## Configuration

### File Locations

- Config: `~/.correctme/config.json`
- PID file: `~/.correctme/correctme.pid`
- Logs: `~/.correctme/correctme.log`
- Error logs: `~/.correctme/correctme.error.log`

### Config File Format

`~/.correctme/config.json`:

```json
{
  "aiProvider": "claude-code",
  "anthropicAPIKey": null,
  "geminiAPIKey": null,
  "openaiAPIKey": null,
  "model": "claude-haiku-4-5-20251001",
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

### "Daemon is already running" but it's not

This can happen if the process was killed abruptly (kill -9, system crash, etc.) leaving a stale PID file. The daemon automatically detects and cleans up stale PID files when you run any command (`status`, `start`, etc.).

If the issue persists, manually remove the PID file:
```bash
rm ~/.correctme/correctme.pid
correctme start -d
```

### "Failed to create event tap"

Accessibility permissions not granted. Go to System Settings → Privacy & Security → Accessibility and enable `/usr/local/bin/correctme`.

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
