#!/bin/sh

# Auto-start CorrectMe when terminal launches.
# Safe to run multiple times - daemon management handles duplicate detection.

# Check if correctme is installed
if ! command -v correctme >/dev/null 2>&1; then
    exit 0
fi

# Check if daemon is already running
if correctme status 2>/dev/null | grep -q "Running"; then
    exit 0
fi

# Start daemon in background
correctme start -d >/dev/null 2>&1
