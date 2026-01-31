#!/bin/bash

set -e

echo "🔨 Building CorrectMe..."

# Build release binary
swift build -c release

# Get the binary path
BINARY_PATH=".build/release/CorrectMe"

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""
echo "Version: $(cat VERSION)"

# Ask user if they want to install (default: yes)
read -p "Install to /usr/local/bin/correctme? [Y/n] " -r
echo ""

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    sudo cp "$BINARY_PATH" /usr/local/bin/correctme
    sudo chmod +x /usr/local/bin/correctme
    echo "✅ Installed to /usr/local/bin/correctme"
    echo ""
    # Optional: enable auto-start via zshrc (recommended for iTerm/Terminal)
    read -p "Enable auto-start on terminal launch (zshrc)? [Y/n] " -r
    echo ""
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        # Remove LaunchAgent if present
        PLIST_DST="$HOME/Library/LaunchAgents/com.correctme.daemon.plist"
        if [ -f "$PLIST_DST" ]; then
            launchctl unload "$PLIST_DST" >/dev/null 2>&1 || true
            rm -f "$PLIST_DST"
        fi

        # Install autostart script
        AUTOSTART_DIR="$HOME/.correctme"
        AUTOSTART_SRC="scripts/correctme-autostart.sh"
        AUTOSTART_DST="$AUTOSTART_DIR/correctme-autostart.sh"
        mkdir -p "$AUTOSTART_DIR"
        cp "$AUTOSTART_SRC" "$AUTOSTART_DST"
        chmod +x "$AUTOSTART_DST"

        # Add to ~/.zshrc if missing
        ZSHRC="$HOME/.zshrc"
        if [ -f "$ZSHRC" ]; then
            if ! /usr/bin/grep -q "correctme-autostart.sh" "$ZSHRC"; then
                {
                    echo ""
                    echo "# CorrectMe auto-start"
                    echo "$AUTOSTART_DST"
                } >> "$ZSHRC"
            fi
        else
            {
                echo "# CorrectMe auto-start"
                echo "$AUTOSTART_DST"
            } > "$ZSHRC"
        fi

        # Restart to ensure new binary is running
        if pgrep -f "/usr/local/bin/correctme run" >/dev/null 2>&1; then
            pkill -f "/usr/local/bin/correctme run" >/dev/null 2>&1 || true
            sleep 0.2
        fi
        "$AUTOSTART_DST" >/dev/null 2>&1 || true

        echo "✅ Auto-start enabled via ~/.zshrc"
    else
        echo "Auto-start not enabled. You can enable it later by running:"
        echo "  ~/.correctme/correctme-autostart.sh"
    fi
    echo ""
    echo "Run 'correctme help' to get started!"
else
    echo ""
    echo "Binary location: $BINARY_PATH"
    echo "You can run it directly or copy it to your PATH manually."
fi
