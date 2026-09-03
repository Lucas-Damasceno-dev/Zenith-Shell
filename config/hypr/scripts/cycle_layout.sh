#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_FILE="${runtime_dir}/hypr-layout-cycle.state"

current_layout="$(
    hyprctl -j getoption general:layout 2>/dev/null \
      | jq -r '.str // .value // ""' 2>/dev/null \
      | tr -d '"'
)"
[[ -n "$current_layout" ]] || current_layout="dwindle"

mode="$current_layout"
if [[ -f "$STATE_FILE" ]]; then
    mode="$(cat "$STATE_FILE" 2>/dev/null || echo "$current_layout")"
fi

next_mode="dwindle"
case "$mode" in
    dwindle)
        hyprctl keyword general:layout master >/dev/null
        next_mode="master"
        ;;
    master)
        hyprctl keyword general:layout dwindle >/dev/null
        hyprctl dispatch togglefloating >/dev/null || true
        hyprctl dispatch centerwindow >/dev/null || true
        next_mode="floating"
        ;;
    floating|*)
        is_floating="$(hyprctl -j activewindow 2>/dev/null | jq -r '.floating // false' 2>/dev/null || echo false)"
        if [[ "$is_floating" == "true" ]]; then
            hyprctl dispatch togglefloating >/dev/null || true
        fi
        hyprctl keyword general:layout dwindle >/dev/null
        next_mode="dwindle"
        ;;
esac

printf '%s\n' "$next_mode" > "$STATE_FILE"
notify-send -a "Hyprland" "Layout" "${next_mode}"
