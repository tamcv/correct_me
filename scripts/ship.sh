#!/bin/sh
# ship.sh — Bump version, commit, tag, and push to trigger GitHub Actions release.
# Usage: ./scripts/ship.sh <version>
# Example: ./scripts/ship.sh 0.3.5

set -e

if [ $# -ne 1 ]; then
    CURRENT="$(cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo "unknown")"
    echo "Usage: $0 <version>"
    echo "Current version: $CURRENT"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Validate semver
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Version must be X.Y.Z (e.g. 0.3.5)"
    exit 1
fi

# Abort if working tree has uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Uncommitted changes — commit or stash them first."
    git status --short
    exit 1
fi

# Check tag doesn't already exist
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "❌ Tag v$VERSION already exists."
    exit 1
fi

echo "🚀 Shipping CorrectMe v$VERSION..."

echo "📝 Bumping version..."
./scripts/bump-version.sh "$VERSION"

echo "💾 Committing..."
git add -A
git commit -m "chore: release v$VERSION"

echo "🏷  Tagging v$VERSION..."
git tag "v$VERSION"

echo "⬆️  Pushing..."
git push origin main --tags

echo ""
echo "✅ v$VERSION pushed — GitHub Actions is building the release."
echo "   https://github.com/tamcv/correct_me/actions"
