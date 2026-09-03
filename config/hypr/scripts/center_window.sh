#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if ! hyprctl dispatch centerwindow >/dev/null 2>&1; then
    notify-send -a "Hyprland" "Center window" "Falha ao centralizar janela"
    exit 1
fi

notify-send -a "Hyprland" "Center window" "Janela centralizada"

