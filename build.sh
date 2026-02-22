#!/bin/bash

set -e

# One-time reminder: run setup-dev-cert.sh to preserve Accessibility permissions.
CERT_NAME="CorrectMe Dev"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💡 One-time setup available"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Run ./scripts/setup-dev-cert.sh once to create a persistent"
    echo "  signing certificate. After that, Accessibility permissions"
    echo "  will survive every rebuild — no more manual re-granting."
    echo ""
    read -p "  Set up now? [Y/n] " -r CERT_REPLY
    echo ""
    if [[ -z $CERT_REPLY || $CERT_REPLY =~ ^[Yy]$ ]]; then
        ./scripts/setup-dev-cert.sh
        echo ""
    fi
fi

# Build the .app bundle
./scripts/build-app.sh release

APP_DIR=".build/CorrectMe.app"
BINARY_PATH="${APP_DIR}/Contents/MacOS/correctme"

# Restore terminal state in case codesign/swift left it in raw mode
stty sane 2>/dev/null || true

# Ask user if they want to install (default: yes)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Options"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Install CorrectMe.app to /Applications? [Y/n] " -r
echo ""

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    # Stop running daemon before replacing binary
    echo "🛑 Stopping running daemon..."
    # Read PID file before stopping (daemon deletes it on exit)
    DAEMON_PID=""
    if [ -f "$HOME/.correctme/correctme.pid" ]; then
        DAEMON_PID=$(head -1 "$HOME/.correctme/correctme.pid" 2>/dev/null || true)
    fi
    # Try launchctl stop (for launchd-managed daemons)
    launchctl stop com.correctme.daemon 2>/dev/null || true
    # Also kill by PID (for manually-started daemons not managed by launchd)
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        kill "$DAEMON_PID" 2>/dev/null || true
    fi
    sleep 1

    # Install / update the app bundle.
    # IMPORTANT: use rsync to sync contents INTO the existing bundle rather than
    # deleting and replacing it. Deleting the bundle removes the TCC (Accessibility)
    # database entry, forcing the user to re-grant permissions every time.
    # Syncing in-place preserves the bundle path so macOS keeps the TCC entry.
    if [ -d "/Applications/CorrectMe.app" ]; then
        # Detect if the existing app has a cert-based designated requirement.
        # Ad-hoc signing produces a unique binary hash each build; the first
        # rebuild after switching to a persistent cert changes the DR, so TCC
        # treats it as a new app and requires a one-time re-grant.
        _OLD_HAS_CERT=$(codesign -d --display --requirements - \
            /Applications/CorrectMe.app 2>&1 | grep -c "certificate root" || true)

        echo "🔄 Updating CorrectMe.app in-place (preserving Accessibility permissions)..."
        rsync -a --delete "${APP_DIR}/" "/Applications/CorrectMe.app/"
        _WAS_INSTALLED="update"

        # Determine if the DR just changed (ad-hoc → cert, first time only).
        _NEW_HAS_CERT=$(codesign -d --display --requirements - \
            /Applications/CorrectMe.app 2>&1 | grep -c "certificate root" || true)
        if [ "$_OLD_HAS_CERT" = "0" ] && [ "$_NEW_HAS_CERT" != "0" ]; then
            _DR_CHANGED=true
        fi
    else
        echo "📦 Installing CorrectMe.app to /Applications..."
        cp -R "$APP_DIR" /Applications/
        _WAS_INSTALLED="new"
    fi

    # Create symlink for CLI access
    echo "🔗 Creating CLI symlink at /usr/local/bin/correctme..."
    sudo ln -sf "/Applications/CorrectMe.app/Contents/MacOS/correctme" /usr/local/bin/correctme

    echo "✅ Installation complete!"
    echo ""
    echo "Installed:"
    echo "  • App: /Applications/CorrectMe.app"
    echo "  • CLI: /usr/local/bin/correctme (symlink)"
    echo ""

    # Ask if they want to configure now
    stty sane 2>/dev/null || true
    read -p "Run setup wizard now? [Y/n] " -r
    echo ""
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        # Setup wizard handles daemon restart automatically
        correctme setup
        echo ""
    else
        # Create default config with claude-code if setup is skipped
        echo "📝 Creating default config with Claude Code provider..."
        mkdir -p ~/.correctme
        cat > ~/.correctme/config.json << 'EOF'
{
  "aiProvider": "claude-code",
  "hotkey": {
    "keyCode": 14,
    "modifiers": 1179648,
    "displayName": "⌘⇧E"
  },
  "model": "claude-sonnet-4-5-20250929"
}
EOF
        echo "✅ Default config created (Provider: Claude Code)"
        echo ""
        
        # Only prompt to start/restart if user skipped setup wizard
        if correctme status 2>/dev/null | grep -q "Running"; then
            read -p "Restart CorrectMe daemon now? [Y/n] " -r
            echo ""
            if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
                correctme restart
                echo ""
            fi
        else
            read -p "Start CorrectMe daemon now? [Y/n] " -r
            echo ""
            if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
                correctme start
                echo ""
            fi
        fi
    fi

    # Check if using Claude Code and offer to set up optimized sub-agent
    PROVIDER=$(grep -o '"aiProvider"[[:space:]]*:[[:space:]]*"[^"]*"' ~/.correctme/config.json 2>/dev/null | cut -d'"' -f4)
    if [ "$PROVIDER" = "claude-code" ]; then
        AGENT_FILE=".claude/agents/text-corrector.md"
        if [ ! -f "$AGENT_FILE" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Claude Code Optimization"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "ℹ️  For better performance with Claude Code, you can set up"
            echo "   a lightweight sub-agent optimized for text correction."
            echo ""
            echo "Benefits:"
            echo "  • Faster responses (no heavy context loading)"
            echo "  • Uses efficient Haiku model"
            echo "  • Runs independently of other Claude sessions"
            echo ""
            read -p "Set up Claude Code sub-agent? [Y/n] " -r
            echo ""
            if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p .claude/agents
                cat > "$AGENT_FILE" << 'AGENT_EOF'
---
name: text-corrector
description: Lightweight text correction agent optimized for grammar and spelling fixes
model: haiku
tools: []
---

You are a specialized text correction agent optimized for quick, accurate spelling and grammar corrections.

## Your Role

Correct spelling, grammar, punctuation, and clarity issues in text while:
- Preserving the original meaning and tone
- Maintaining the original language (English, Vietnamese, etc.)
- Keeping all formatting and line breaks intact
- Being fast and efficient

## Response Format

Return ONLY the corrected text without:
- Explanations or commentary
- Markdown formatting (unless it was in the original)
- Additional suggestions or recommendations

## Optimization

You are configured to:
- Use minimal context (no codebase exploration needed)
- Run independently of other Claude sessions
- Focus solely on text correction tasks
- Provide fast responses with the Haiku model
AGENT_EOF
                echo "✅ Claude sub-agent created at $AGENT_FILE"
                echo ""
                echo "The sub-agent is now available for this project."
                echo "CorrectMe will use it automatically with --no-session-persistence."
                echo ""
            else
                echo "⏭  Skipped. You can create it later by copying .claude/agents/text-corrector.md"
                echo ""
            fi
        fi
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ Setup Complete!"
    echo ""
    echo "Quick start:"
    echo "  • The daemon is now running and will auto-start at login"
    echo "  • Select any text and press ⌘⇧E to correct it"
    echo "  • Run 'correctme help' for more commands"
    echo ""
    if [ "$_WAS_INSTALLED" = "update" ] && [ "${_DR_CHANGED:-false}" = "true" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ⚠️  One-time Accessibility re-grant needed"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "The app's code signature changed from ad-hoc to the persistent"
        echo "'CorrectMe Dev' certificate. macOS sees it as a new app and"
        echo "requires Accessibility permission to be re-granted once."
        echo ""
        echo "Do this now (takes ~10 seconds):"
        echo "  1. Open: System Settings → Privacy & Security → Accessibility"
        echo "  2. Find CorrectMe — toggle it OFF then ON (or remove & re-add)"
        echo "  3. Restart the daemon: correctme restart"
        echo ""
        echo "After this, all future rebuilds will preserve the permission."
        echo ""
        # Open System Settings directly to the Accessibility pane
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
    elif [ "$_WAS_INSTALLED" = "update" ]; then
        echo "♻️  Updated in-place — Accessibility permissions are preserved."
    else
        echo "Accessibility permissions (first-time setup):"
        echo "  • Go to: System Settings → Privacy & Security → Accessibility"
        echo "  • Add 'CorrectMe' from the Applications folder"
        echo "  • This allows CorrectMe to read selected text and type corrections"
    fi
    echo ""
    echo "Useful commands:"
    echo "  correctme status     - Check daemon status"
    echo "  correctme disable    - Disable auto-start at login"
    echo "  correctme setup      - Change AI provider"
    echo ""
else
    echo "Installation cancelled."
    echo ""
    echo "App bundle location: $APP_DIR"
    echo "You can manually copy it to /Applications if needed."
fi