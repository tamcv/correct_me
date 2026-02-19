#!/bin/bash

set -e

VERSION=$(cat VERSION 2>/dev/null || echo "0.2.1")
BUILD_TYPE="${1:-release}"

echo "🔨 Building CorrectMe.app (${BUILD_TYPE})..."
echo "Version: ${VERSION}"
echo ""

# Build the binary
if [ "$BUILD_TYPE" = "release" ]; then
    swift build -c release
    BINARY_PATH=".build/release/CorrectMe"
else
    swift build
    BINARY_PATH=".build/debug/CorrectMe"
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed - binary not found at $BINARY_PATH"
    exit 1
fi

echo "✅ Binary built successfully"
echo ""

# Create .app bundle structure
APP_NAME="CorrectMe.app"
APP_DIR=".build/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating .app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "${MACOS_DIR}/correctme"
chmod +x "${MACOS_DIR}/correctme"

# Copy Info.plist and update version
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${CONTENTS_DIR}/Info.plist" 2>/dev/null || true

echo "✅ App bundle created at: ${APP_DIR}"
echo ""

# Determine signing identity.
# A persistent local certificate preserves macOS Accessibility permissions
# across rebuilds (the designated requirement stays stable). Ad-hoc signing
# generates a new binary hash every build, which invalidates the TCC entry.
CERT_NAME="CorrectMe Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    SIGN_IDENTITY="$CERT_NAME"
    echo "🔑 Signing with persistent certificate: $CERT_NAME"
else
    SIGN_IDENTITY="-"
    echo "⚠️  Signing ad-hoc (Accessibility permissions will need re-granting after each rebuild)"
    echo "   Run ./scripts/setup-dev-cert.sh once to fix this permanently."
fi

# Code sign the bundle
echo "🔐 Code signing the app bundle..."
codesign --force --deep --sign "$SIGN_IDENTITY" "${APP_DIR}"
echo "✅ Code signing complete"
echo ""

# Verify the bundle
echo "🔍 Verifying bundle..."
codesign -dvvv "${APP_DIR}" 2>&1 | head -5
echo ""

echo "✅ Build complete!"
echo ""
echo "App bundle location: ${APP_DIR}"
echo "Binary path: ${MACOS_DIR}/correctme"
echo ""
