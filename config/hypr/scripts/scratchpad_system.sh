#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

workspace_name="sys"
class_name="scratchpad-system"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v kitty >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

if pgrep -f "kitty --class ${class_name}" >/dev/null 2>&1; then
    hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null || true
    exit 0
fi

kitty --class "$class_name" --title "System Terminal" >/dev/null 2>&1 &
sleep 0.15
hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null || true
