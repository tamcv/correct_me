#!/bin/sh

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "$VERSION" > "$ROOT_DIR/VERSION"

cat > "$ROOT_DIR/Sources/Version.swift" <<EOF
import Foundation

enum AppVersion {
    static let current = "$VERSION"
}
EOF

echo "Updated version to $VERSION"
