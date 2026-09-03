#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

special_name="pinned"
active_ws="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.name // ""' 2>/dev/null || true)"

if [[ "$active_ws" == "special:${special_name}" ]]; then
    hyprctl dispatch togglespecialworkspace "$special_name" >/dev/null
    notify-send -a "Hyprland" "Workspace pin" "Pinned workspace oculto"
    exit 0
fi

addr="$(hyprctl -j activewindow 2>/dev/null | jq -r '.address // ""' 2>/dev/null || true)"
if [[ -n "$addr" ]]; then
    [[ "$addr" == 0x* ]] || addr="0x${addr}"
    hyprctl dispatch movetoworkspace "special:${special_name},address:${addr}" >/dev/null
fi

hyprctl dispatch togglespecialworkspace "$special_name" >/dev/null
notify-send -a "Hyprland" "Workspace pin" "Pinned workspace exibido"

