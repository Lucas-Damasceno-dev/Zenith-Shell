#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

term="${1:-}"
[[ -n "$term" ]] || exit 0

encoded="$(jq -rn --arg q "$term" '$q|@uri')"
curl -fsSL --connect-timeout 8 --max-time 20 \
    "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=pt&dt=t&q=${encoded}" \
    | jq -r '.[0][0][0] // ""' 2>/dev/null || true

