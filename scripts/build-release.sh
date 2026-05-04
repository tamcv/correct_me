#!/bin/bash
#
# build-release.sh — Build a signed, notarized DMG for distribution.
#
# Usage:
#   ./scripts/build-release.sh
#
# Environment variables (optional — without them, creates unsigned DMG):
#   DEVELOPER_ID        — Signing identity, e.g. "Developer ID Application: Name (TEAMID)"
#   APPLE_ID            — Apple ID email for notarization
#   APPLE_APP_PASSWORD  — App-specific password for notarization
#   APPLE_TEAM_ID       — Apple Developer Team ID
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "0.0.0")
APP_NAME="CorrectMe"
DMG_NAME="${APP_NAME}-v${VERSION}-macos.dmg"
ENTITLEMENTS="$PROJECT_DIR/Resources/CorrectMe.entitlements"

echo "╔══════════════════════════════════════════════╗"
echo "║  CorrectMe Release Builder v${VERSION}          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Step 1: Build the .app bundle ──
echo "▶ Step 1: Building .app bundle..."
chmod +x "$SCRIPT_DIR/build-app.sh"
"$SCRIPT_DIR/build-app.sh" release

APP_DIR="$PROJECT_DIR/.build/${APP_NAME}.app"
if [ ! -d "$APP_DIR" ]; then
    echo "❌ App bundle not found at $APP_DIR"
    exit 1
fi
echo ""

# ── Step 2: Code sign ──
SIGNED=false
if [ -n "$DEVELOPER_ID" ]; then
    echo "▶ Step 2: Code signing with Developer ID..."

    if [ ! -f "$ENTITLEMENTS" ]; then
        echo "❌ Entitlements file not found: $ENTITLEMENTS"
        exit 1
    fi

    codesign --force --deep --options runtime \
        --sign "$DEVELOPER_ID" \
        --entitlements "$ENTITLEMENTS" \
        "$APP_DIR"

    echo "  Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
    echo "✅ Code signing complete"
    SIGNED=true
else
    echo "▶ Step 2: Skipping code signing (DEVELOPER_ID not set)"
    echo "  The DMG will be unsigned — for local testing only."
fi
echo ""

# ── Step 3: Create DMG ──
echo "▶ Step 3: Creating DMG installer..."

RELEASE_DIR="$PROJECT_DIR/.build/release-dmg"
DMG_STAGING="$RELEASE_DIR/dmg-staging"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$DMG_STAGING"

# Copy .app and create Applications symlink for drag-and-drop install
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "✅ DMG created: $DMG_PATH"
echo ""

# ── Step 4: Sign the DMG ──
if [ "$SIGNED" = true ]; then
    echo "▶ Step 4: Signing DMG..."
    codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"
    echo "✅ DMG signed"
else
    echo "▶ Step 4: Skipping DMG signing (unsigned build)"
fi
echo ""

# ── Step 5: Notarize ──
if [ "$SIGNED" = true ] && [ -n "$APPLE_ID" ] && [ -n "$APPLE_APP_PASSWORD" ] && [ -n "$APPLE_TEAM_ID" ]; then
    echo "▶ Step 5: Submitting for notarization..."
    SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --output-format json 2>&1)
    SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
    if [ -z "$SUBMISSION_ID" ]; then
        echo "❌ Failed to get submission ID. Output:"
        echo "$SUBMIT_OUTPUT"
        exit 1
    fi
    echo "  Submission ID: $SUBMISSION_ID"
    echo "$SUBMISSION_ID" > "$RELEASE_DIR/notarization_id.txt"

    # When NOTARIZE_WAIT=false CI handles polling in a separate job
    if [ "${NOTARIZE_WAIT:-true}" = "false" ]; then
        echo "  Skipping poll — CI will poll in publish job."
        echo "✅ DMG submitted for notarization"
    else
        echo "  Polling for result (retries on network errors)..."
        POLL_INTERVAL=30
        MAX_ATTEMPTS=120  # 120 × 30s = 60 minutes max
        ATTEMPT=0
        STATUS=""
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            sleep $POLL_INTERVAL
            ATTEMPT=$((ATTEMPT + 1))
            INFO_OUTPUT=$(xcrun notarytool info "$SUBMISSION_ID" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_APP_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --output-format json 2>&1) || true
            STATUS=$(echo "$INFO_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
            echo "  [${ATTEMPT}/${MAX_ATTEMPTS}] Status: ${STATUS:-network error, retrying...}"
            if [ "$STATUS" = "Accepted" ]; then break; fi
            if [ "$STATUS" = "Invalid" ] || [ "$STATUS" = "Rejected" ]; then
                echo "❌ Notarization failed with status: $STATUS"
                xcrun notarytool log "$SUBMISSION_ID" \
                    --apple-id "$APPLE_ID" \
                    --password "$APPLE_APP_PASSWORD" \
                    --team-id "$APPLE_TEAM_ID" 2>&1 || true
                exit 1
            fi
        done

        if [ "$STATUS" != "Accepted" ]; then
            echo "❌ Notarization timed out after $((MAX_ATTEMPTS * POLL_INTERVAL))s (last status: $STATUS)"
            exit 1
        fi

        echo "  Stapling notarization ticket..."
        xcrun stapler staple "$DMG_PATH"
        echo "✅ Notarization complete"
    fi
else
    echo "▶ Step 5: Skipping notarization (credentials not set)"
fi
echo ""

# ── Step 6: Generate checksum ──
echo "▶ Step 6: Generating SHA256 checksum..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "$SHA256" > "$RELEASE_DIR/sha256.txt"
echo "  SHA256: $SHA256"
echo ""

# ── Summary ──
echo "╔══════════════════════════════════════════════╗"
echo "║  Build Complete!                             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  DMG:    $DMG_PATH"
echo "  SHA256: $SHA256"
echo "  Signed: $SIGNED"
DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
echo "  Size:   $DMG_SIZE"
echo ""

if [ "$SIGNED" != true ]; then
    echo "⚠️  This is an unsigned build. To create a signed, notarized DMG:"
    echo "  export DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\""
    echo "  export APPLE_ID=\"your@email.com\""
    echo "  export APPLE_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo "  export APPLE_TEAM_ID=\"XXXXXXXXXX\""
    echo "  ./scripts/build-release.sh"
    echo ""
fi
