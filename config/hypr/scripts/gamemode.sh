#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
status_file="${state_dir}/gamemode.status"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v notify-send >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

mkdir -p "$state_dir"
[[ -f "$status_file" ]] || printf '0\n' > "$status_file"

get_state() {
    cat "$status_file" 2>/dev/null || echo "0"
}

set_state() {
    printf '%s\n' "$1" > "$status_file"
}

enable_mode() {
    hyprctl keyword animations:enabled 0 >/dev/null 2>&1
    hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1
    hyprctl keyword decoration:shadow:enabled 0 >/dev/null 2>&1
    set_state 1
    notify-send -u low -i "input-gaming" "Game Mode" "Activated: Max Performance"
}

disable_mode() {
    hyprctl reload >/dev/null 2>&1
    set_state 0
    notify-send -u low -i "input-gaming" "Game Mode" "Deactivated: Normal Mode"
}

current_state="$(get_state)"
if [[ "$current_state" == "0" ]]; then
    if ! enable_mode; then
        disable_mode || true
        notify-send -u low -i "input-gaming" "Game Mode" "Activation failed; state restored"
        exit 1
    fi
else
    disable_mode
fi
