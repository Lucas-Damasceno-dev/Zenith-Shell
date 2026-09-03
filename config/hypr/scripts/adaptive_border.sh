#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    command -v grim >/dev/null 2>&1 || exit 1
    command -v convert >/dev/null 2>&1 || exit 1
    command -v socat >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

resolve_socket() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local base_dir="${runtime_dir}/hypr"
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"

    if [[ -n "$sig" && -S "${base_dir}/${sig}/.socket2.sock" ]]; then
        printf '%s\n' "${base_dir}/${sig}/.socket2.sock"
        return 0
    fi

    sig="$(find "$base_dir" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null \
      | sort -nr \
      | head -n1 \
      | awk '{print $2}')"
    [[ -n "$sig" && -S "${base_dir}/${sig}/.socket2.sock" ]] || return 1
    printf '%s\n' "${base_dir}/${sig}/.socket2.sock"
}

handle_focus() {
    local active_win class at_x at_y color rgb
    active_win="$(hyprctl activewindow -j 2>/dev/null || true)"
    class="$(printf '%s' "$active_win" | jq -r '.class // ""' 2>/dev/null || true)"
    [[ -n "$class" && "$class" != "null" ]] || return 0

    at_x="$(printf '%s' "$active_win" | jq -r '.at[0] // empty' 2>/dev/null || true)"
    at_y="$(printf '%s' "$active_win" | jq -r '.at[1] // empty' 2>/dev/null || true)"
    [[ -n "$at_x" && -n "$at_y" ]] || return 0

    color="$(
        grim -g "${at_x},${at_y} 100x100" -t ppm - 2>/dev/null \
            | convert - -resize 1x1 txt:- 2>/dev/null \
            | grep -oE '#[0-9A-Fa-f]{6}' \
            | head -1 || true
    )"
    [[ -n "$color" ]] || return 0

    rgb="${color#\#}"
    hyprctl keyword general:col.active_border "#${rgb}FF #${rgb}88 45deg" >/dev/null 2>&1 || true
}

while true; do
    socket_path="$(resolve_socket || true)"
    [[ -n "$socket_path" ]] || { sleep 2; continue; }

    socat -u "UNIX-CONNECT:${socket_path}" - 2>/dev/null | while read -r line; do
        if [[ "$line" == activewindow* ]]; then
            sleep 0.08
            handle_focus
        fi
    done || true
    sleep 1
done
