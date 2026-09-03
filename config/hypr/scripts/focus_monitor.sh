#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

direction="${1:-next}"
if [[ "$direction" != "next" && "$direction" != "prev" ]]; then
    direction="next"
fi

json="$(hyprctl -j monitors 2>/dev/null || true)"
if [[ -z "$json" || "$json" == "null" ]]; then
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 1
fi

mapfile -t names < <(printf '%s' "$json" | jq -r '.[].name')
count="${#names[@]}"
if [[ "$count" -lt 2 ]]; then
    notify-send -a "Hyprland" "Monitor focus" "Apenas um monitor disponível"
    exit 0
fi

focused_idx="$(printf '%s' "$json" | jq -r 'to_entries[] | select(.value.focused == true) | .key' | head -n1)"
if [[ -z "$focused_idx" ]]; then
    focused_idx=0
fi

if [[ "$direction" == "next" ]]; then
    target_idx=$(( (focused_idx + 1) % count ))
else
    target_idx=$(( (focused_idx - 1 + count) % count ))
fi

target="${names[$target_idx]}"
hyprctl dispatch focusmonitor "$target" >/dev/null
notify-send -a "Hyprland" "Monitor focus" "$target"

