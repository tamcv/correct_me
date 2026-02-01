#!/bin/sh

set -e

REPO="tamcv/correct_me"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer currently supports macOS only."
    exit 1
fi

LATEST_JSON_URL="https://raw.githubusercontent.com/$REPO/main/dist/latest.json"
echo "Checking latest metadata: $LATEST_JSON_URL"
LATEST_JSON="$(curl -fsSL "$LATEST_JSON_URL" 2>/dev/null || true)"
if [ -n "$LATEST_JSON" ]; then
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag\"' | /usr/bin/sed -E 's/.*\"tag\": \"([^\"]+)\".*/\1/')"
    ASSET="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"asset\"' | /usr/bin/sed -E 's/.*\"asset\": \"([^\"]+)\".*/\1/')"
    SHA256_EXPECTED="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"sha256\"' | /usr/bin/sed -E 's/.*\"sha256\": \"([^\"]+)\".*/\1/')"
else
    echo "Falling back to GitHub Releases API..."
    LATEST_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag_name\"' | /usr/bin/sed -E 's/.*\"tag_name\": \"([^\"]+)\".*/\1/')"
    VERSION="${TAG#v}"
    ASSET="CorrectMe-v$VERSION-macos.zip"
fi

if [ -z "$TAG" ]; then
    echo "Failed to resolve latest release tag."
    exit 1
fi

VERSION="${TAG#v}"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
echo "Downloading release: $URL"

TMP_DIR="$(mktemp -d)"
ZIP_PATH="$TMP_DIR/$ASSET"

echo "⬇️  Downloading $ASSET..."
curl -fsSL "$URL" -o "$ZIP_PATH"

if [ -n "$SHA256_EXPECTED" ]; then
    SHA256_ACTUAL="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
    if [ "$SHA256_ACTUAL" != "$SHA256_EXPECTED" ]; then
        echo "SHA256 mismatch. Aborting."
        exit 1
    fi
fi

echo "📦 Installing CorrectMe..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

# Remove old installation if exists
if [ -d "/Applications/CorrectMe.app" ]; then
    echo "🗑  Removing old version..."
    rm -rf /Applications/CorrectMe.app
fi

# Install .app to Applications
echo "📱 Installing CorrectMe.app to /Applications..."
mv "$TMP_DIR/CorrectMe.app" /Applications/

# Create CLI symlink
echo "🔗 Creating CLI symlink at /usr/local/bin/correctme..."
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
