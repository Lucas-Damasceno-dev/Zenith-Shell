#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

hyprctl reload >/dev/null 2>&1 || true
systemctl --user restart quickshell >/dev/null 2>&1 || true
notify-send -a "Hyprland" "Emergency reset" "Compositor recarregado e Quickshell reiniciado"

