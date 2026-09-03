#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

history_file="$(qs_state_file "utility-hub-capture-history")"
legacy_history="/tmp/utility-hub-capture-history"
lines="${1:-10}"
if [[ ! "$lines" =~ ^[0-9]+$ ]]; then
    lines=10
fi

if [[ ! -f "$history_file" && -f "$legacy_history" ]]; then
    history_file="$legacy_history"
fi

[[ -f "$history_file" ]] || exit 0

# Read history, filter to existing files only, return latest $lines
valid_count=0
temp_out="$(mktemp "$(qs_runtime_root)/hist-XXXXXX.tmp")"
trap 'rm -f "$temp_out"' EXIT

# Process backwards to get the most recent valid items first
tac "$history_file" 2>/dev/null | while IFS=$'\t' read -r ts path kind rest; do
    [[ -n "$path" && -f "$path" ]] || continue
    printf '%s\t%s\t%s\n' "$ts" "$path" "${kind:-screenshot}" >> "$temp_out"
    valid_count=$((valid_count + 1))
    if (( valid_count >= lines )); then
        break
    fi
done

if [[ -f "$temp_out" && -s "$temp_out" ]]; then
    tac "$temp_out"
fi
