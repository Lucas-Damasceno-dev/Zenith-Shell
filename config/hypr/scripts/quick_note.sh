#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

note_dir="${HOME}/Notes"
note_file="${note_dir}/quick-note.md"

mkdir -p "$note_dir"
if [[ ! -f "$note_file" ]]; then
    {
        echo "# Quick Note"
        echo
        echo "- $(date +'%Y-%m-%d %H:%M')"
        echo
    } > "$note_file"
fi

if pgrep -f "kitty --class scratchpad-note" >/dev/null 2>&1; then
    hyprctl dispatch togglespecialworkspace notes >/dev/null || true
    exit 0
fi

kitty --class scratchpad-note --title "Quick Note" sh -lc "nvim '$note_file'" >/dev/null 2>&1 &
sleep 0.15
hyprctl dispatch togglespecialworkspace notes >/dev/null || true
notify-send -a "Hyprland" "Quick note" "$(basename "$note_file")"
