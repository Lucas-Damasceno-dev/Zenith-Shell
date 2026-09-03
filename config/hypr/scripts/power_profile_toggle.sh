#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    notify-send -a "Hyprland" "Power profile" "powerprofilesctl não encontrado"
    exit 1
fi

current="$(powerprofilesctl get 2>/dev/null || echo balanced)"
case "$current" in
    performance) next="balanced" ;;
    balanced) next="power-saver" ;;
    power-saver) next="performance" ;;
    *) next="balanced" ;;
esac

powerprofilesctl set "$next"
quickshell ipc --any-display call ipcHandler triggerPowerProfileOsd "$next" >/dev/null 2>&1 || true
notify-send -a "Hyprland" "Power profile" "Perfil: ${next}"

