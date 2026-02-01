#!/bin/bash

set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Uninstall CorrectMe                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "This will remove:"
echo "  • Binary: /usr/local/bin/correctme"
echo "  • Config: ~/.correctme/"
echo "  • Auto-start from ~/.zshrc"
echo "  • LaunchAgent (if installed)"
echo ""

read -p "Are you sure you want to uninstall? [y/N] " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

REMOVED=()

# 1. Stop daemon if running
if command -v correctme &> /dev/null; then
    if correctme status 2>/dev/null | grep -q "Running"; then
        echo "🛑 Stopping daemon..."
        correctme stop 2>/dev/null || true
        REMOVED+=("Stopped daemon")
    fi
fi

# 2. Remove LaunchAgent
PLIST="$HOME/Library/LaunchAgents/com.correctme.daemon.plist"
if [ -f "$PLIST" ]; then
    echo "🗑  Removing LaunchAgent..."
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    REMOVED+=("Removed LaunchAgent")
fi

# 3. Remove auto-start from .zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    if /usr/bin/grep -q "correctme-autostart.sh" "$ZSHRC"; then
        echo "🗑  Removing auto-start from ~/.zshrc..."
        sed -i '' '/correctme-autostart.sh/d' "$ZSHRC"
        sed -i '' '/# CorrectMe auto-start/d' "$ZSHRC"
        REMOVED+=("Removed auto-start from ~/.zshrc")
    fi
fi

# 4. Remove config directory
if [ -d "$HOME/.correctme" ]; then
    echo "🗑  Removing config directory..."
    rm -rf "$HOME/.correctme"
    REMOVED+=("Removed ~/.correctme/")
fi

# 5. Remove binary
if [ -f "/usr/local/bin/correctme" ]; then
    echo "🗑  Removing binary..."
    sudo rm -f /usr/local/bin/correctme
    REMOVED+=("Removed /usr/local/bin/correctme")
fi

# Summary
echo ""
echo "✅ Uninstall complete!"
echo ""

if [ ${#REMOVED[@]} -gt 0 ]; then
    echo "Removed:"
    for item in "${REMOVED[@]}"; do
        echo "  ✓ $item"
    done
fi

echo ""
echo "👋 Thanks for using CorrectMe!"
echo ""
