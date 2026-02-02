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
   - Click the **+** button and select **CorrectMe** from Applications folder
   - Enable the toggle next to CorrectMe
   - **Important**: If the daemon was already running, restart it:
     ```bash
     correctme restart
     ```

2. **Start the daemon** (if not already started):
   ```bash
   correctme start
   ```
   This will start the daemon in background and enable auto-start at login.

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

### Auto-start Management

CorrectMe automatically enables auto-start at login when you run `correctme start` for the first time. It uses a macOS LaunchAgent that runs independently of terminal sessions.

```bash
# Check if auto-start is enabled
correctme status

# Disable auto-start at login
correctme disable

# Re-enable auto-start at login
correctme enable
```

The LaunchAgent plist is stored at `~/Library/LaunchAgents/com.correctme.daemon.plist`.

## Features

- 🎯 **Global hotkey** - Works in any app (default: ⌘⇧E)
- 💬 **Cursor HUD** - Small floating window near cursor shows real-time correction status
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

### Claude Code Optimization (Recommended)

If you're using the Claude Code provider, you can significantly improve performance by configuring a lightweight sub-agent specifically for text correction:

1. **During Installation**: The build and install scripts will automatically offer to set this up for you.

2. **Manual Setup**: Create the sub-agent configuration file at `.claude/agents/text-corrector.md` (included in this repo).

This optimization:
- Uses `--no-session-persistence` to avoid loading heavy context from other Claude sessions
- Configures a specialized sub-agent optimized for quick text corrections
- Uses the fast Haiku model by default
- Runs independently without codebase context loading

The sub-agent is automatically available when working in this project directory.

## Installation (from source)

```bash
# Clone the project
git clone https://github.com/tamcv/correct_me.git
cd correct_me

# Build & install
chmod +x build.sh
chmod +x scripts/build-app.sh
./build.sh

# Follow prompts to:
# 1. Install CorrectMe.app to /Applications
# 2. Run setup wizard
# 3. Start the daemon
```

The build script will:
- Build the .app bundle with proper Info.plist
- Install to `/Applications/CorrectMe.app` with code signing
- Create a symlink at `/usr/local/bin/correctme` for CLI access
- Optionally run setup and start the daemon

Note: Update the repo URL in `scripts/install.sh` if you fork this project.

### Auto-update

```bash
correctme update
```

### Uninstall

If you no longer need CorrectMe:

```bash
# Option 1: Use uninstall command (interactive, safer)
correctme uninstall

# Option 2: Use uninstall script (complete removal including binary)
curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/uninstall.sh | sh

# Option 3: Manual removal
correctme disable                                          # Disable auto-start
sudo rm /usr/local/bin/correctme                           # Remove binary
rm -rf ~/.correctme                                        # Remove config
```

## Setup

### 1. Grant Accessibility Permissions

CorrectMe needs accessibility access to read selected text and simulate keyboard input.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Navigate to **Applications** and select **CorrectMe.app**
4. Enable the toggle next to CorrectMe

The app will now appear in the Accessibility list as "CorrectMe" instead of a binary path.

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
# Start in background (auto-enables at login)
correctme start
```

## Usage

1. **Start the daemon**: `correctme start`
2. **Select text** in any application
3. **Press ⌘⇧E** (or your custom hotkey)
4. **Text is replaced** with the corrected version

## Commands

### Daemon Management

| Command | Description |
|---------|-------------|
| `correctme start` | Start daemon in background (auto-enables at login) |
| `correctme stop` | Stop the daemon |
| `correctme restart` | Restart the daemon |
| `correctme status` | Check daemon status and uptime |
| `correctme enable` | Enable auto-start at login |
| `correctme disable` | Disable auto-start at login |

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
| `correctme uninstall` | Uninstall CorrectMe (removes config, auto-start, prompts for binary removal) |
| `correctme help` | Show help message |

## Configuration

### File Locations

- Config: `~/.correctme/config.json`
- PID file: `~/.correctme/correctme.pid`
- LaunchAgent: `~/Library/LaunchAgents/com.correctme.daemon.plist`
- Logs: `/tmp/correctme.log`
- Error logs: `/tmp/correctme.error.log`

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
correctme start
```

### "Failed to create event tap"

Accessibility permissions not granted. Go to System Settings → Privacy & Security → Accessibility and add **CorrectMe.app** from the Applications folder.

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
