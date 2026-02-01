#!/bin/sh

# Auto-start CorrectMe once per machine session.
# Safe to run multiple times (e.g., from tmux shells).

if ! command -v correctme >/dev/null 2>&1; then
    exit 0
fi

# Check if daemon is already running
if correctme status | grep -q "Running"; then
    # If config changed recently, restart to pick up new hotkey/model.
    CONFIG_FILE="$HOME/.correctme/config.json"
    PID_FILE="$HOME/.correctme/correctme.pid"
    if [ -f "$PID_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ]; then
            START_TIME=$(ps -p "$PID" -o lstart= 2>/dev/null)
            if [ -n "$START_TIME" ] && find "$CONFIG_FILE" -newermt "$START_TIME" >/dev/null 2>&1; then
                correctme restart >/dev/null 2>&1
            fi
        fi
    fi
    exit 0
fi

# Start daemon in background
correctme start -d >/dev/null 2>&1
