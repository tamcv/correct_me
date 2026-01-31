#!/bin/sh

# Auto-start CorrectMe once per machine session.
# Safe to run multiple times (e.g., from tmux shells).

if ! command -v correctme >/dev/null 2>&1; then
    exit 0
fi

if pgrep -f "/usr/local/bin/correctme run" >/dev/null 2>&1; then
    exit 0
fi

nohup /usr/local/bin/correctme run >/tmp/correctme.log 2>/tmp/correctme.error.log &
