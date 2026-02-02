#!/bin/bash

set -e

# Build the .app bundle
./scripts/build-app.sh release

APP_DIR=".build/CorrectMe.app"
BINARY_PATH="${APP_DIR}/Contents/MacOS/correctme"

# Ask user if they want to install (default: yes)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Options"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Install CorrectMe.app to /Applications? [Y/n] " -r
echo ""

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    # Remove old app if exists
    if [ -d "/Applications/CorrectMe.app" ]; then
        echo "🗑  Removing old version..."
        rm -rf /Applications/CorrectMe.app
    fi

    # Copy .app bundle to /Applications
    echo "📦 Installing CorrectMe.app to /Applications..."
    cp -R "$APP_DIR" /Applications/

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
    echo "Accessibility permissions:"
    echo "  • Go to: System Settings → Privacy & Security → Accessibility"
    echo "  • Add 'CorrectMe' from the Applications folder"
    echo "  • This allows CorrectMe to read selected text and type corrections"
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