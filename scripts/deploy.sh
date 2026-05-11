#!/bin/sh
set -e

# 1. Stop daemon and wait for it to fully exit BEFORE replacing binary
echo "Stopping daemon..."
if command -v correctme >/dev/null 2>&1; then
    correctme stop 2>/dev/null || true
fi
# Kill any lingering instances by process name just in case
pkill -x correctme 2>/dev/null || true
sleep 0.8

# 2. Copy binary only (framework files are unchanged between dev builds)
BINARY_SRC=".build/debug/CorrectMe"
BINARY_DST="/Applications/CorrectMe.app/Contents/MacOS/correctme"

# Prefer debug binary if it exists, otherwise fall back to .build/CorrectMe.app bundle binary
[ -f "$BINARY_SRC" ] || BINARY_SRC=".build/CorrectMe.app/Contents/MacOS/correctme"

echo "Installing app..."
NEED_SUDO=false
if ! cp "$BINARY_SRC" "$BINARY_DST" 2>/dev/null; then
    sudo cp "$BINARY_SRC" "$BINARY_DST"
    NEED_SUDO=true
fi

# 3. Re-sign binary so TCC keeps tracking by bundle ID (not binary hash)
CERT_NAME="Developer ID Application: Tam Chau (854GZSP8M7)"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    if [ "$NEED_SUDO" = true ]; then
        sudo codesign --force --sign "$CERT_NAME" "$BINARY_DST" 2>/dev/null
    else
        codesign --force --sign "$CERT_NAME" "$BINARY_DST" 2>/dev/null \
            || sudo codesign --force --sign "$CERT_NAME" "$BINARY_DST" 2>/dev/null
    fi
    echo "✓ Re-signed with $CERT_NAME"
else
    echo "⚠️  No '$CERT_NAME' certificate found — accessibility permissions may need re-granting"
fi

# 5. Start fresh
echo "Starting daemon..."
correctme start

echo "✓ Done"
