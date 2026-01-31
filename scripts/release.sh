#!/bin/sh

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DIST_DIR="$ROOT_DIR/dist"
BIN_PATH="$ROOT_DIR/.build/release/CorrectMe"

if [ ! -f "$VERSION_FILE" ]; then
    echo "VERSION file not found."
    exit 1
fi

VERSION="$(cat "$VERSION_FILE")"

echo "🔨 Building CorrectMe v$VERSION..."
cd "$ROOT_DIR"
swift build -c release

if [ ! -f "$BIN_PATH" ]; then
    echo "❌ Build failed: $BIN_PATH not found."
    exit 1
fi

mkdir -p "$DIST_DIR"
ZIP_NAME="CorrectMe-v$VERSION-macos.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
LATEST_JSON="$DIST_DIR/latest.json"

echo "📦 Packaging $ZIP_NAME..."
rm -f "$ZIP_PATH"
cd "$DIST_DIR"
cp "$BIN_PATH" "./correctme"
chmod +x "./correctme"
zip -q -r "$ZIP_NAME" "./correctme"
rm -f "./correctme"

echo "📝 Writing latest.json..."
cat > "$LATEST_JSON" <<EOF
{
  "version": "$VERSION",
  "tag": "v$VERSION",
  "asset": "$ZIP_NAME",
  "sha256": "$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
}
EOF

echo "✅ Release artifact: $ZIP_PATH"
echo "🔒 SHA256:"
shasum -a 256 "$ZIP_PATH"

if command -v gh >/dev/null 2>&1; then
    echo "🚀 Publishing GitHub Release v$VERSION..."
    gh release create "v$VERSION" "$ZIP_PATH" \
        --title "v$VERSION" \
        --notes "CorrectMe v$VERSION"
    echo "✅ Release published"
else
    echo "ℹ️  gh not found. Upload $ZIP_PATH to GitHub Releases manually."
fi
