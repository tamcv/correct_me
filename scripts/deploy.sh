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

# 2. Replace app bundle
echo "Installing app..."
rsync -a --delete .build/CorrectMe.app/ /Applications/CorrectMe.app/

# 3. Clear quarantine flag (prevents macOS from showing permission prompts)
xattr -c /Applications/CorrectMe.app 2>/dev/null || true

# 4. Re-sign so TCC keeps tracking by bundle ID (not binary hash)
CERT_NAME="CorrectMe Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    codesign --force --deep --sign "$CERT_NAME" /Applications/CorrectMe.app/ 2>/dev/null
    echo "✓ Re-signed with $CERT_NAME"
else
    echo "⚠️  No '$CERT_NAME' certificate found — accessibility permissions may need re-granting"
    echo "   Run ./scripts/setup-dev-cert.sh once to fix this permanently"
fi

# 5. Start fresh
echo "Starting daemon..."
correctme start

echo "✓ Done"
