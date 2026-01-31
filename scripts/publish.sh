#!/bin/sh

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

./scripts/bump-version.sh "$VERSION"

git add VERSION Sources/Version.swift
git commit -m "Bump version to $VERSION"
git tag "v$VERSION"

./scripts/release.sh

if [ -f "dist/latest.json" ]; then
    git add dist/latest.json
    git commit -m "Update latest.json for v$VERSION"
fi

git push
git push --tags

echo "✅ Published v$VERSION"
