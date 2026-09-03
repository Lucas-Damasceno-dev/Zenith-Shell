#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

term="${1:-}"

hyprctl -j workspaces 2>/dev/null | jq -r '
    sort_by(.lastwindow // 0) | reverse
    | .[]
    | [(.id|tostring), (.name // ""), (.windows // 0 | tostring)]
    | @tsv
' | while IFS=$'\t' read -r ws_id ws_name ws_windows; do
    line="${ws_id} ${ws_name}"
    if [[ -n "$term" ]] && [[ "${line,,}" != *"${term,,}"* ]]; then
        continue
    fi
    printf '%s\t%s\t%s\n' "$ws_id" "$ws_name" "$ws_windows"
done | head -n 20

