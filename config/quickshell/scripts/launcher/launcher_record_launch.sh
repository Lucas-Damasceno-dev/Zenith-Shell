#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
# shellcheck disable=SC1091
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

app_id="${1:-}"
[[ -n "$app_id" ]] || exit 0

cache_dir="${HOME}/.cache"
frecency_file="${cache_dir}/launcher-frecency.json"
audit_file="${cache_dir}/launcher-frecency-audit.log"

mkdir -p "$cache_dir"
[[ -f "$frecency_file" ]] || echo "{}" > "$frecency_file"

tmp_file="$(mktemp "$(qs_runtime_root)/launcher-frecency-XXXXXX.json")"
audit_tmp="$(mktemp "$(qs_runtime_root)/launcher-frecency-audit-XXXXXX.log")"
trap 'rm -f "$tmp_file" "$audit_tmp"' EXIT
lock_file="$(qs_runtime_file "launcher-frecency.lock")"

{
    flock -x 9
    if ! jq --arg app "$app_id" '
        . as $root
        | if type != "object" then {} else . end
        | .[$app] = ((.[$app] // 0) + 1)
    ' "$frecency_file" > "$tmp_file" 2>/dev/null; then
        jq -n --arg app "$app_id" '{($app): 1}' > "$tmp_file"
    fi
    mv -f "$tmp_file" "$frecency_file"

    count="$(jq -r --arg app "$app_id" '.[$app] // 0' "$frecency_file" 2>/dev/null || echo 0)"
    printf '%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$app_id" "$count" > "$audit_tmp"
    if [[ -f "$audit_file" ]]; then
        tail -n 399 "$audit_file" >> "$audit_tmp" 2>/dev/null || true
    fi
    mv -f "$audit_tmp" "$audit_file"

    if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )) && (( count % 100 == 0 )); then
        backup_file="${cache_dir}/launcher-frecency-backup-$(date +%s).json"
        cp -f "$frecency_file" "$backup_file" 2>/dev/null || true
        find "$cache_dir" -maxdepth 1 -type f -name 'launcher-frecency-backup-*.json' -mtime +7 -delete 2>/dev/null || true
    fi
} 9>"$lock_file"
