#!/bin/bash
#
# Quick UI test — build, launch, screenshot, then hand off to Claude agent for analysis.
#
# Usage:
#   ./scripts/ui-test.sh          # just capture screenshots
#   ./scripts/ui-test.sh --agent  # capture + invoke Claude ui-tester agent
#

set -e

cd "$(dirname "$0")/.."

SCREENSHOT_DIR="/tmp/correctme-ui-test"
mkdir -p "$SCREENSHOT_DIR"

echo "🔨 Building..."
swift build 2>&1 | tail -1

echo "🚀 Launching CorrectMe..."
.build/debug/CorrectMe start &
APP_PID=$!
sleep 2

# Check if app started
if ! kill -0 $APP_PID 2>/dev/null; then
    echo "❌ App failed to start"
    exit 1
fi
echo "✅ App running (PID: $APP_PID)"

echo "📸 Capturing screenshot..."
screencapture -x "$SCREENSHOT_DIR/full-screen.png"
echo "   Saved: $SCREENSHOT_DIR/full-screen.png"

# Try to open menu bar dropdown and capture
echo "📸 Attempting to capture menu bar dropdown..."
osascript -e 'tell application "System Events" to click menu bar item 1 of menu bar 2 of application process "CorrectMe"' 2>/dev/null || true
sleep 1
screencapture -x "$SCREENSHOT_DIR/menu-open.png"
echo "   Saved: $SCREENSHOT_DIR/menu-open.png"

# Close menu
osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true

echo "🛑 Stopping app..."
.build/debug/CorrectMe stop 2>/dev/null || kill $APP_PID 2>/dev/null || true
sleep 1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Screenshots ready for analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  $SCREENSHOT_DIR/full-screen.png"
echo "  $SCREENSHOT_DIR/menu-open.png"
echo ""

if [ "$1" = "--agent" ]; then
    echo "🤖 Invoking Claude ui-tester agent..."
    echo ""
    claude --agent ui-tester "Analyze the UI screenshots at $SCREENSHOT_DIR/ and report findings."
else
    echo "  To analyze with Claude agent:"
    echo "    claude --agent ui-tester \"Analyze screenshots at $SCREENSHOT_DIR/\""
    echo ""
fi
