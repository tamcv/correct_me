#!/bin/sh

set -e

log() {
    echo "==> $1"
}

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

log "Bumping version to $VERSION"
./scripts/bump-version.sh "$VERSION"

log "Committing version bump"
git add VERSION Sources/Version.swift
if git diff --cached --quiet; then
    log "No version changes to commit"
else
    git commit -m "Bump version to $VERSION"
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    log "Tag v$VERSION already exists"
else
    git tag "v$VERSION"
fi

log "Building and creating release artifacts"
./scripts/release.sh

if [ -f "dist/latest.json" ]; then
    log "Committing latest.json"
    git add dist/latest.json
    git commit -m "Update latest.json for v$VERSION"
fi

log "Pushing commits"
git push
log "Pushing tags"
git push --tags

log "Published v$VERSION"
