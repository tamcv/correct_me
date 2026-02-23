#!/bin/bash

set -e

# One-time reminder: run setup-dev-cert.sh to preserve Accessibility permissions.
CERT_NAME="CorrectMe Dev"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  💡 One-time setup available"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Run ./scripts/setup-dev-cert.sh once to create a persistent"
    echo "  signing certificate. After that, Accessibility permissions"
    echo "  will survive every rebuild — no more manual re-granting."
    echo ""
    read -p "  Set up now? [Y/n] " -r CERT_REPLY
    echo ""
    if [[ -z $CERT_REPLY || $CERT_REPLY =~ ^[Yy]$ ]]; then
        ./scripts/setup-dev-cert.sh
        echo ""
    fi
fi

# Build the .app bundle
./scripts/build-app.sh release

# Restore terminal state in case codesign/swift left it in raw mode
stty sane 2>/dev/null || true

APP_DIR=".build/CorrectMe.app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  App bundle: ${APP_DIR}"
echo ""
echo "  To run:"
echo "    open ${APP_DIR}"
echo ""
echo "  Or via CLI:"
echo "    ${APP_DIR}/Contents/MacOS/correctme start"
echo ""
