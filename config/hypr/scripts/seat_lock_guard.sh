#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v loginctl >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_file="${runtime_dir}/hypr-seat-active.state"
session_id="${XDG_SESSION_ID:-}"

if [[ -z "$session_id" ]]; then
    session_id="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER" '$3==u {print $1; exit}')"
fi

[[ -n "$session_id" ]] || exit 0

active="$(loginctl show-session "$session_id" -p Active --value 2>/dev/null || echo yes)"
active="$(printf '%s' "$active" | tr '[:upper:]' '[:lower:]')"
prev="yes"
[[ -f "$state_file" ]] && prev="$(cat "$state_file" 2>/dev/null || echo yes)"

if [[ "$prev" == "yes" && "$active" == "no" ]]; then
    loginctl lock-session "$session_id" >/dev/null 2>&1 || true
fi

printf '%s\n' "$active" > "$state_file"
