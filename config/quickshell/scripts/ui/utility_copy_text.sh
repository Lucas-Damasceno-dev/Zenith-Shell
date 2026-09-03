#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

primary="0"
if [[ "${1:-}" == "--primary" ]]; then
    primary="1"
    shift
fi

text="${1:-}"
if [[ "$primary" == "1" ]]; then
    printf '%s' "$text" | wl-copy --primary >/dev/null 2>&1
else
    printf '%s' "$text" | wl-copy >/dev/null 2>&1
fi

