#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

module_stats() {
    local proc="$1"
    local cpu_budget="$2"
    local mem_budget="$3"
    local pid cpu mem
    pid="$(pgrep -x "$proc" | head -n1 || true)"
    if [[ -z "$pid" ]]; then
        printf '{"name":"%s","running":false,"cpu":0,"mem":0,"budget":{"cpu":%s,"mem":%s},"ok":true}' "$proc" "$cpu_budget" "$mem_budget"
        return
    fi
    read -r cpu mem <<< "$(ps -p "$pid" -o %cpu=,%mem= 2>/dev/null | xargs || echo "0 0")"
    cpu="${cpu:-0}"
    mem="${mem:-0}"
    awk -v n="$proc" -v c="$cpu" -v m="$mem" -v cb="$cpu_budget" -v mb="$mem_budget" '
    BEGIN {
      ok = ((c+0)<=cb && (m+0)<=mb) ? "true" : "false";
      printf("{\"name\":\"%s\",\"running\":true,\"cpu\":%s,\"mem\":%s,\"budget\":{\"cpu\":%s,\"mem\":%s},\"ok\":%s}", n, c+0, m+0, cb+0, mb+0, ok);
    }'
}

quickshell_json="$(module_stats quickshell 12 4)"
pipewire_json="$(module_stats pipewire 10 4)"
rec_json="$(module_stats wf-recorder 45 10)"

printf '{"modules":[%s,%s,%s]}\n' "$quickshell_json" "$pipewire_json" "$rec_json" \
    | jq '
        .ok = ( [.modules[].ok] | all )
        | .cpu = ((.modules[] | select(.name=="quickshell") | .cpu) // 0)
        | .mem = ((.modules[] | select(.name=="quickshell") | .mem) // 0)
        | .budget = { cpu: 12, mem: 4 }
    '
