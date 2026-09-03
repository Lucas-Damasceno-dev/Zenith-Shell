#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v notify-send >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

macro="${1:-dev}"

case "$macro" in
    dev)
        hyprctl dispatch workspace 3 >/dev/null
        if ! pgrep -x kitty >/dev/null 2>&1; then kitty >/dev/null 2>&1 & fi
        ;;
    comms)
        hyprctl dispatch workspace 2 >/dev/null
        if ! pgrep -x discord >/dev/null 2>&1 && ! pgrep -x vesktop >/dev/null 2>&1; then
            vesktop >/dev/null 2>&1 &
        fi
        ;;
    focus)
        hyprctl dispatch workspace 5 >/dev/null
        hyprctl dispatch togglespecialworkspace notes >/dev/null 2>&1 || true
        ;;
    clean)
        hyprctl dispatch workspace 1 >/dev/null
        ;;
    *)
        notify-send -a "Hyprland" "Workspace macro" "Macro inválida: $macro"
        exit 1
        ;;
esac

notify-send -a "Hyprland" "Workspace macro" "Macro executada: ${macro}"
