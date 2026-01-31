#!/bin/sh

# Auto-start CorrectMe once per machine session.
# Safe to run multiple times (e.g., from tmux shells).

if ! command -v correctme >/dev/null 2>&1; then
    exit 0
fi

if pgrep -f "/usr/local/bin/correctme run" >/dev/null 2>&1; then
    # If config changed recently, restart to pick up new hotkey/model.
    CONFIG_FILE="$HOME/.correctme/config.json"
    PID=$(pgrep -f "/usr/local/bin/correctme run" | head -n 1)
    if [ -n "$PID" ] && [ -f "$CONFIG_FILE" ]; then
        START_TIME=$(ps -p "$PID" -o lstart= 2>/dev/null)
        if [ -n "$START_TIME" ] && find "$CONFIG_FILE" -newermt "$START_TIME" >/dev/null 2>&1; then
            pkill -f "/usr/local/bin/correctme run" >/dev/null 2>&1 || true
            sleep 0.2
        else
            exit 0
        fi
    else
        exit 0
    fi
fi

nohup /usr/local/bin/correctme run >/tmp/correctme.log 2>/tmp/correctme.error.log &
