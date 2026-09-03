#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    command -v cliphist >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

entry_id="${1:-}"
[[ -n "$entry_id" ]] || exit 0

cliphist list | awk -F'\t' -v id="$entry_id" '$1 == id { print $0; exit }' | cliphist delete 2>/dev/null || true
