#!/bin/sh

set -e

REPO="tam-chau/correct_me"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer currently supports macOS only."
    exit 1
fi

LATEST_JSON="$(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/dist/latest.json" 2>/dev/null || true)"
if [ -n "$LATEST_JSON" ]; then
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag\"' | /usr/bin/sed -E 's/.*\"tag\": \"([^\"]+)\".*/\1/')"
    ASSET="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"asset\"' | /usr/bin/sed -E 's/.*\"asset\": \"([^\"]+)\".*/\1/')"
    SHA256_EXPECTED="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"sha256\"' | /usr/bin/sed -E 's/.*\"sha256\": \"([^\"]+)\".*/\1/')"
else
    LATEST_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
    TAG="$(echo "$LATEST_JSON" | /usr/bin/grep -m 1 '\"tag_name\"' | /usr/bin/sed -E 's/.*\"tag_name\": \"([^\"]+)\".*/\1/')"
fi

if [ -z "$TAG" ]; then
    echo "Failed to resolve latest release tag."
    exit 1
fi

VERSION="${TAG#v}"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

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

echo "✅ Installed CorrectMe $VERSION"
echo "Run: correctme setup"
