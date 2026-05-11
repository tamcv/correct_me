#!/bin/sh
set -e

APP="/Applications/CorrectMe.app"
BINARY_DST="$APP/Contents/MacOS/correctme"

# 1. Stop daemon and wait for it to fully exit BEFORE replacing binary
echo "Stopping daemon..."
if [ -x "$BINARY_DST" ]; then
    "$BINARY_DST" stop 2>/dev/null || true
fi
# Kill any lingering instances by process name just in case
pkill -x correctme 2>/dev/null || true
sleep 0.8

# 2. Copy binary only (framework files are unchanged between dev builds)
BINARY_SRC=".build/debug/CorrectMe"
# Prefer debug binary if it exists, otherwise fall back to .build/CorrectMe.app bundle binary
[ -f "$BINARY_SRC" ] || BINARY_SRC=".build/CorrectMe.app/Contents/MacOS/correctme"

echo "Installing app..."
NEED_SUDO=false
if ! cp "$BINARY_SRC" "$BINARY_DST" 2>/dev/null; then
    NEED_SUDO=true
    DST_DIR="$(dirname "$BINARY_DST")"
    # Strip quarantine (clears App Translocation), schg flags, and deny ACLs
    # from the entire bundle so the directory becomes writable again.
    sudo xattr -d com.apple.quarantine "$APP" 2>/dev/null || true
    sudo chflags -R noschg "$DST_DIR" 2>/dev/null || true
    sudo chmod -RN "$DST_DIR" 2>/dev/null || true
    if ! sudo cp "$BINARY_SRC" "$BINARY_DST" 2>/dev/null; then
        # Last resort: full bundle replacement.
        # TCC tracks by bundle ID + cert, so accessibility permission survives
        # as long as we re-sign with the same Developer ID certificate below.
        echo "  -> full bundle reinstall"
        sudo rm -rf "$APP"
        sudo ditto ".build/CorrectMe.app" "$APP"
    fi
    sudo chmod 755 "$BINARY_DST"
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

# 4. Start fresh (use full path — sh subprocess may not have app in PATH)
echo "Starting daemon..."
"$BINARY_DST" start

echo "✓ Done"
