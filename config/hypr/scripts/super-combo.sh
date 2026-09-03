#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_file="${runtime_dir}/hypr-super-last-combo"
printf '%s\n' "$(date +%s%3N)" > "$state_file"
