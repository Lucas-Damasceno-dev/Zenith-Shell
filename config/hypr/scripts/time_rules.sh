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
    quickshell ipc call ipcHandler setDndOn >/dev/null 2>&1 || true
    echo "night"
    exit 0
fi

if (( hour >= 7 && hour < 18 )); then
    brightnessctl set 80% >/dev/null 2>&1 || true
    quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true
    echo "day"
    exit 0
fi

brightnessctl set 60% >/dev/null 2>&1 || true
quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true
echo "evening"
