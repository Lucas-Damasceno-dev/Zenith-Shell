#!/usr/bin/env bash
# toggle_settings.sh - Toggle or launch Zenith Shell Settings Menu
set -euo pipefail

QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

# Try triggering running Quickshell via IPC
if quickshell -p "$QS_DIR" ipc --any-display call ipcHandler toggleSettings 2>/dev/null; then
    exit 0
fi

# Fallback 1: Zenith Engine v2 daemon socket
if [[ -S "${XDG_RUNTIME_DIR:-/run/user/1000}/zenith.sock" ]]; then
    if zenith toggle Settings 2>/dev/null; then
        exit 0
    fi
fi

# Fallback 2: launch standalone quickshell settings window
if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -p "$QS_DIR/settings.qml"
fi

echo "Error: Neither active Zenith daemon nor Quickshell could be launched." >&2
exit 1
