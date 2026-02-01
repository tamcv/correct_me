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

echo "📦 Installing to /usr/local/bin/correctme..."
unzip -q "$ZIP_PATH" -d "$TMP_DIR"
sudo mv "$TMP_DIR/correctme" /usr/local/bin/correctme
sudo chmod +x /usr/local/bin/correctme

# Code sign to prevent macOS Gatekeeper issues
echo "🔐 Code signing binary..."
sudo codesign --force --deep --sign - /usr/local/bin/correctme

echo ""
echo "✅ Installed CorrectMe $VERSION"
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
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installation Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next steps:"
    echo "  1. Grant Accessibility permissions:"
    echo "     System Settings → Privacy & Security → Accessibility"
    echo "     Add and enable: /usr/local/bin/correctme"
    echo ""
    echo "  2. Start the daemon:"
    echo "     correctme start -d"
    echo ""
    echo "  3. Select text and press ⌘⇧E to correct it!"
    echo ""
else
    echo "Setup skipped. To configure later, run:"
    echo "  correctme setup"
    echo ""
fi
