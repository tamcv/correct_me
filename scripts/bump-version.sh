#!/bin/sh
# bump-version.sh — Update the version everywhere it appears.
# Usage: ./scripts/bump-version.sh <version>
# Example: ./scripts/bump-version.sh 0.4.0

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.4.0"
    exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Validate semver format
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Version must be in semver format: X.Y.Z"
    exit 1
fi

echo "Bumping version to $VERSION..."

# 1. VERSION file (used by build scripts)
echo "$VERSION" > "$ROOT_DIR/VERSION"

# 2. Sources/Version.swift
cat > "$ROOT_DIR/Sources/Version.swift" <<EOF
import Foundation

enum AppVersion {
    static let current = "$VERSION"

    // Build timestamp - updated during compilation
    static let buildDate: String = {
        #if DEBUG
        return "Debug Build"
        #else
        return "Release Build"
        #endif
    }()

    static var fullVersion: String {
        return "v\(current) (\(buildDate))"
    }
}
EOF

# 3. Info.plist (CFBundleShortVersionString + CFBundleVersion)
# CFBundleVersion = major*100 + minor*10 + patch as integer
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)
BUNDLE_VERSION=$((MAJOR * 100 + MINOR * 10 + PATCH))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$ROOT_DIR/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$ROOT_DIR/Resources/Info.plist"

echo "✅ Updated version to $VERSION"
echo "   VERSION file, Sources/Version.swift, Resources/Info.plist"
