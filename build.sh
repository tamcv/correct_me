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
    fi

    # Check if daemon is running and start/restart accordingly
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