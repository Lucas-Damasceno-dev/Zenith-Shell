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

state_file="$(qs_state_file "quickshell-focus-state.json")"
metrics_file="$(qs_state_file "quickshell-focus-metrics.json")"
lock_file="$(qs_runtime_file "quickshell-focus-metrics.lock")"

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

now="$(date +%s)"
current_app="$(hyprctl -j activewindow 2>/dev/null | jq -r '.class // "unknown"' 2>/dev/null || echo "unknown")"
current_app="$(printf '%s' "$current_app" | tr -cd '[:alnum:]._-')"
[[ -n "$current_app" ]] || current_app="unknown"

prev_app=""
prev_ts="$now"
if [[ -f "$state_file" ]]; then
    prev_app="$(jq -r '.app // ""' "$state_file" 2>/dev/null || echo "")"
    prev_ts="$(jq -r '.ts // 0' "$state_file" 2>/dev/null || echo 0)"
fi

if [[ ! "$prev_ts" =~ ^[0-9]+$ ]]; then
    prev_ts="$now"
fi

delta=$(( now - prev_ts ))
if (( delta < 0 )); then delta=0; fi
if (( delta > 120 )); then delta=120; fi

metrics_json="$(cat "$metrics_file" 2>/dev/null || echo '{"apps":{}}')"
metrics_json="$(printf '%s' "$metrics_json" | jq '
    if type != "object" then {apps:{}} else . end
    | .apps = (.apps // {})
')"

if [[ -n "$prev_app" && "$delta" -gt 0 ]]; then
    metrics_json="$(printf '%s' "$metrics_json" | jq --arg app "$prev_app" --argjson d "$delta" '
        .apps[$app] = ((.apps[$app] // {}) | .seconds = ((.seconds // 0) + $d))
    ')"
fi

if [[ -n "$prev_app" && "$current_app" != "$prev_app" ]]; then
    metrics_json="$(printf '%s' "$metrics_json" | jq --arg app "$current_app" '
        .apps[$app] = ((.apps[$app] // {}) | .interruptions = ((.interruptions // 0) + 1))
    ')"
fi

metrics_json="$(printf '%s' "$metrics_json" | jq --argjson now "$now" '
    .lastUpdate = $now
    | .topApps = (
        (.apps // {})
        | to_entries
        | map({
            app: .key,
            minutes: ((.value.seconds // 0) / 60),
            interruptions: (.value.interruptions // 0)
          })
        | sort_by(.minutes)
        | reverse
        | .[0:8]
      )
')"

{
    flock -x 9
    printf '%s\n' "$metrics_json" > "$metrics_file"
    printf '{"app":"%s","ts":%s}\n' "$current_app" "$now" > "$state_file"
} 9>"$lock_file"
