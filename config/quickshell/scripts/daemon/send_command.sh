#!/usr/bin/env bash
set -e

if [[ "$1" == "--self-test" ]]; then
    command -v socat &>/dev/null || { echo "FAIL: socat not found"; exit 1; }
    echo "ok"
    exit 0
fi

SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell_commands.sock"

if [[ ! -S "$SOCKET" ]]; then
    notify-send -a "Quickshell" "Context Daemon" "Socket de comandos não encontrado"
    exit 1
fi

printf '%s' "$1" | timeout 3 socat -t 2 - UNIX-CONNECT:"$SOCKET"
