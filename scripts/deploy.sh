#!/bin/sh

rsync -a --delete .build/CorrectMe.app/ /Applications/CorrectMe.app/

# Re-sign after rsync so macOS TCC tracks by bundle ID (not binary hash).
# Without this, accessibility permissions are revoked on every deploy.
CERT_NAME="CorrectMe Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    codesign --force --deep --sign "$CERT_NAME" /Applications/CorrectMe.app/ 2>/dev/null
    echo "✓ Re-signed with $CERT_NAME"
else
    echo "⚠️  No '$CERT_NAME' certificate found — accessibility permissions will need re-granting"
    echo "   Run ./scripts/setup-dev-cert.sh once to fix this permanently"
fi

correctme restart
