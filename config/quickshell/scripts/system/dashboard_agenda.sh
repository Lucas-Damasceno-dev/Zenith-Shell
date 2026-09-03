#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

json_file="${HOME}/.config/quickshell/agenda.json"
ics_file="${HOME}/.config/quickshell/agenda.ics"

tmp="$(mktemp "$(qs_runtime_root)/quickshell-agenda-XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [[ -f "$json_file" ]]; then
    jq -r '
        if type == "array" then . else [] end
        | .[]
        | "json\t\(.title // .name // "Task")\t\(.due // .date // .when // "")"
    ' "$json_file" 2>/dev/null >> "$tmp" || true
fi

if [[ -f "$ics_file" ]]; then
    awk '
        BEGIN {summary=""; datev=""}
        /^BEGIN:VEVENT/ {summary=""; datev=""}
        /^SUMMARY:/ {summary=substr($0,9)}
        /^DTSTART/ {
            split($0, a, ":");
            datev=a[2];
        }
        /^END:VEVENT/ {
            if (summary != "")
                printf "ics\t%s\t%s\n", summary, datev;
        }
    ' "$ics_file" >> "$tmp" || true
fi

if [[ ! -s "$tmp" ]]; then
    exit 0
fi

tail -n 12 "$tmp"
