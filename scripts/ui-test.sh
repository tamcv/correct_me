#!/bin/bash
#
# Invoke the ui-tester Claude agent for full E2E testing.
#
# Usage:
#   ./scripts/ui-test.sh                  # full E2E test
#   ./scripts/ui-test.sh "custom prompt"  # custom test instructions
#
# Prerequisites:
#   - iTerm/Terminal must have Screen Recording permission
#     (System Settings → Privacy & Security → Screen Recording)
#   - CorrectMe must have Accessibility permission
#   - claude CLI must be available
#

set -e

cd "$(dirname "$0")/.."

# Verify screencapture works
if ! screencapture -x /tmp/correctme-screencap-test.png 2>/dev/null; then
    echo "❌ screencapture failed."
    echo "   Grant Screen Recording permission to your terminal app:"
    echo "   System Settings → Privacy & Security → Screen Recording"
    exit 1
fi
rm -f /tmp/correctme-screencap-test.png

# Verify claude CLI exists
if ! command -v claude &>/dev/null; then
    echo "❌ claude CLI not found."
    echo "   Install: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

PROMPT="${1:-Run the full E2E UI test sequence. Test everything: build, launch, menu bar, preferences, and text correction in Notes app. Report all results.}"

echo "🤖 Launching ui-tester agent..."
echo "   Prompt: ${PROMPT}"
echo ""

claude --agent ui-tester "$PROMPT"
