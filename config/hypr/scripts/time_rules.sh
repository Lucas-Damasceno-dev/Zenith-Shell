#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

hour="$(date +%-H)"

if (( hour >= 22 || hour < 7 )); then
    brightnessctl set 35% >/dev/null 2>&1 || true
    if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/zenith.sock" ]] || pgrep -x zenith >/dev/null 2>&1; then
        zenith eval 'Zenith.Services.set_dnd(true)' >/dev/null 2>&1 || true
    else
        quickshell ipc call ipcHandler setDndOn >/dev/null 2>&1 || true
    fi
    echo "night"
    exit 0
fi

if (( hour >= 7 && hour < 18 )); then
    brightnessctl set 80% >/dev/null 2>&1 || true
    if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/zenith.sock" ]] || pgrep -x zenith >/dev/null 2>&1; then
        zenith eval 'Zenith.Services.set_dnd(false)' >/dev/null 2>&1 || true
    else
        quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true
    fi
    echo "day"
    exit 0
fi

brightnessctl set 60% >/dev/null 2>&1 || true
if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/zenith.sock" ]] || pgrep -x zenith >/dev/null 2>&1; then
    zenith eval 'Zenith.Services.set_dnd(false)' >/dev/null 2>&1 || true
else
    quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true
fi
echo "evening"
