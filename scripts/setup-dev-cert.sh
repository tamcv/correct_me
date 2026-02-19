#!/bin/bash
# One-time setup: creates a persistent local code signing certificate.
#
# WHY: macOS Accessibility permissions are tied to an app's code signature.
# Ad-hoc signing (codesign --sign -) generates a unique binary hash each time,
# so every rebuild looks like a different app — Accessibility must be re-granted.
#
# This script creates "CorrectMe Dev" in your login keychain once.
# build-app.sh will use it automatically, producing a stable designated
# requirement across rebuilds, so TCC never needs to re-validate.

set -e

CERT_NAME="CorrectMe Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Already done?
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "✓ Signing certificate '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  One-time Developer Certificate Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creates a persistent signing certificate so Accessibility"
echo "permissions are preserved across all future rebuilds."
echo ""

if ! command -v openssl &>/dev/null; then
    echo "❌ openssl not found."
    echo "   Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Generate self-signed certificate ----------------------------------------

cat > "$TMP_DIR/cert.conf" << 'OPENSSL_CONF'
[req]
default_bits       = 2048
distinguished_name = req_dn
x509_extensions    = v3_codesign
prompt             = no

[req_dn]
CN = CorrectMe Dev
O  = CorrectMe Development

[v3_codesign]
basicConstraints    = critical, CA:FALSE
keyUsage            = critical, digitalSignature
extendedKeyUsage    = codeSigning
subjectKeyIdentifier = hash
OPENSSL_CONF

echo "🔑 Generating certificate..."

openssl req -x509 \
    -newkey rsa:2048 \
    -keyout "$TMP_DIR/key.pem" \
    -out    "$TMP_DIR/cert.pem" \
    -days   3650 \
    -nodes \
    -config "$TMP_DIR/cert.conf" 2>/dev/null

# Export as PKCS12 (try OpenSSL 3.x --legacy flag first, then 1.x without)
openssl pkcs12 -export \
    -out    "$TMP_DIR/cert.p12" \
    -inkey  "$TMP_DIR/key.pem" \
    -in     "$TMP_DIR/cert.pem" \
    -passout pass: \
    -legacy 2>/dev/null || \
openssl pkcs12 -export \
    -out    "$TMP_DIR/cert.p12" \
    -inkey  "$TMP_DIR/key.pem" \
    -in     "$TMP_DIR/cert.pem" \
    -passout pass: 2>/dev/null

# --- Import to login keychain ------------------------------------------------

echo "📥 Importing to login keychain..."

if ! security import "$TMP_DIR/cert.p12" \
    -k "$KEYCHAIN" \
    -P "" \
    -T /usr/bin/codesign \
    -f pkcs12 2>/dev/null; then
    echo "❌ Failed to import certificate into keychain."
    exit 1
fi

# --- Trust for code signing (will prompt for password / Touch ID) -------------

echo ""
echo "🔒 A system dialog will ask for your password to trust the certificate."
echo "   Click 'Always Allow' or enter your password when prompted."
echo ""

if ! security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$TMP_DIR/cert.pem" 2>/dev/null; then
    echo ""
    echo "⚠️  Automatic trust setup was declined or failed."
    echo ""
    echo "Complete it manually (one time only):"
    echo "  1. Open Keychain Access (Cmd+Space → 'Keychain Access')"
    echo "  2. Select the 'login' keychain, find '$CERT_NAME'"
    echo "  3. Double-click → expand 'Trust'"
    echo "  4. Set 'Code Signing' to 'Always Trust', close (enter password)"
    echo "  5. Re-run: ./scripts/setup-dev-cert.sh"
    exit 1
fi

# --- Verify ------------------------------------------------------------------

echo ""
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "✅ Certificate '$CERT_NAME' is ready."
    echo ""
    echo "All future builds will use this certificate."
    echo "Accessibility permissions will be preserved across rebuilds — no more"
    echo "manual re-granting in System Settings."
else
    echo "⚠️  Certificate was imported but is not yet trusted for code signing."
    echo "   Follow the manual steps printed above."
    exit 1
fi
