#!/bin/sh
#
# install.sh — Download and install CorrectMe.
#
# Supports both DMG and ZIP release formats.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh
#
set -e

REPO="tamcv/correct_me"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer currently supports macOS only."
    exit 1
fi

# ── Fetch release metadata ──
LATEST_JSON_URL="https://raw.githubusercontent.com/$REPO/main/dist/latest.json"
echo "Checking latest metadata: $LATEST_JSON_URL"
LATEST_JSON="$(curl -fsSL "$LATEST_JSON_URL" 2>/dev/null || true)"
if [ -n "$LATEST_JSON" ]; then
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag\"' | /usr/bin/sed -E 's/.*\"tag\": \"([^\"]+)\".*/\1/')"
    ASSET="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"asset\"' | /usr/bin/sed -E 's/.*\"asset\": \"([^\"]+)\".*/\1/')"
    SHA256_EXPECTED="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"sha256\"' | /usr/bin/sed -E 's/.*\"sha256\": \"([^\"]+)\".*/\1/')"
    FORMAT="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"format\"' | /usr/bin/sed -E 's/.*\"format\": \"([^\"]+)\".*/\1/')"
else
    echo "Falling back to GitHub Releases API..."
    LATEST_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag_name\"' | /usr/bin/sed -E 's/.*\"tag_name\": \"([^\"]+)\".*/\1/')"
    VERSION="${TAG#v}"
    # Try DMG first, fall back to ZIP
    ASSET="CorrectMe-${TAG}-macos.dmg"
    FORMAT="dmg"
fi

if [ -z "$TAG" ]; then
    echo "Failed to resolve latest release tag."
    exit 1
fi

# Auto-detect format from asset name if not in metadata
if [ -z "$FORMAT" ]; then
    case "$ASSET" in
        *.dmg) FORMAT="dmg" ;;
        *.zip) FORMAT="zip" ;;
        *) FORMAT="zip" ;;
    esac
fi

VERSION="${TAG#v}"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
echo "Downloading release: $URL"

TMP_DIR="$(mktemp -d)"
DOWNLOAD_PATH="$TMP_DIR/$ASSET"

echo "⬇️  Downloading $ASSET..."
curl -fsSL "$URL" -o "$DOWNLOAD_PATH"

# ── Verify checksum ──
if [ -n "$SHA256_EXPECTED" ]; then
    SHA256_ACTUAL="$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')"
    if [ "$SHA256_ACTUAL" != "$SHA256_EXPECTED" ]; then
        echo "❌ SHA256 mismatch. Aborting."
        echo "   Expected: $SHA256_EXPECTED"
        echo "   Got:      $SHA256_ACTUAL"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    echo "✅ Checksum verified"
fi

# ── Install ──
echo "📦 Installing CorrectMe v${VERSION}..."

# Stop running daemon if any
if [ -f "$HOME/.correctme/correctme.pid" ]; then
    OLD_PID=$(head -1 "$HOME/.correctme/correctme.pid" 2>/dev/null || true)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "  Stopping running daemon (PID: $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
    fi
fi

# Remove old installation
if [ -d "/Applications/CorrectMe.app" ]; then
    echo "  Removing old CorrectMe.app..."
    rm -rf /Applications/CorrectMe.app
fi

if [ "$FORMAT" = "dmg" ]; then
    # ── DMG install ──
    echo "  Mounting DMG..."
    MOUNT_POINT="$(hdiutil attach "$DOWNLOAD_PATH" -nobrowse -quiet | tail -1 | awk -F'\t' '{print $NF}')"

    if [ ! -d "$MOUNT_POINT/CorrectMe.app" ]; then
        echo "❌ CorrectMe.app not found in DMG"
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
        rm -rf "$TMP_DIR"
        exit 1
    fi

    echo "  Copying to /Applications..."
    cp -R "$MOUNT_POINT/CorrectMe.app" /Applications/

    echo "  Unmounting DMG..."
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
else
    # ── ZIP install (legacy) ──
    echo "  Extracting ZIP..."
    unzip -q "$DOWNLOAD_PATH" -d "$TMP_DIR"

    if [ -d "$TMP_DIR/CorrectMe.app" ]; then
        cp -R "$TMP_DIR/CorrectMe.app" /Applications/
    else
        echo "❌ CorrectMe.app not found in ZIP"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

# ── Verify code signature ──
if codesign --verify --deep --strict /Applications/CorrectMe.app 2>/dev/null; then
    echo "✅ Code signature verified"
else
    echo "⚠️  App is not code-signed (development build)"
fi

# Clean up old CLI symlink if exists
if [ -L "/usr/local/bin/correctme" ] || [ -f "/usr/local/bin/correctme" ]; then
    echo "  Removing old CLI symlink..."
    sudo rm -f /usr/local/bin/correctme 2>/dev/null || true
fi

# Create CLI symlink to app bundle
echo "  Creating CLI symlink..."
sudo mkdir -p /usr/local/bin
sudo ln -sf /Applications/CorrectMe.app/Contents/MacOS/correctme /usr/local/bin/correctme

echo ""
echo "✅ Installed CorrectMe $VERSION"
echo ""
echo "Installed:"
echo "  • App: /Applications/CorrectMe.app"
echo "  • CLI: /usr/local/bin/correctme"
echo ""

# Clean up
rm -rf "$TMP_DIR"

# Ask if user wants to run setup now
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup CorrectMe"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Run setup wizard now? [Y/n] " -r
echo ""

if [ -z "$REPLY" ] || echo "$REPLY" | grep -iq "^y"; then
    correctme setup
    echo ""
fi

# Ask if they want to start the daemon
read -p "Start CorrectMe daemon now? [Y/n] " -r
echo ""

if [ -z "$REPLY" ] || echo "$REPLY" | grep -iq "^y"; then
    correctme start
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "CorrectMe is now installed and will auto-start at login!"
echo ""
echo "Quick start:"
echo "  • Select any text and press ⌘⇧E to correct it"
echo "  • Run 'correctme status' to check daemon status"
echo "  • Run 'correctme help' for more commands"
echo ""
echo "To disable auto-start at login:"
echo "  correctme disable"
echo ""
