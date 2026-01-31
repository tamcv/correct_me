#!/bin/bash

set -e

echo "🔨 Building CorrectMe..."

# Build release binary
swift build -c release

# Get the binary path
BINARY_PATH=".build/release/CorrectMe"

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Ask user if they want to install (default: yes)
read -p "Install to /usr/local/bin/correctme? [Y/n] " -r
echo ""

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    sudo cp "$BINARY_PATH" /usr/local/bin/correctme
    sudo chmod +x /usr/local/bin/correctme
    echo "✅ Installed to /usr/local/bin/correctme"
    echo ""
    echo "Run 'correctme help' to get started!"
else
    echo ""
    echo "Binary location: $BINARY_PATH"
    echo "You can run it directly or copy it to your PATH manually."
fi
