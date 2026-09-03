#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pid_file="${runtime_dir}/quickshell-caffeine.pid"

if [[ "${1:-}" == "--self-test" ]]; then
  echo "ok"
  exit 0
fi

pid=""
if [[ -f "$pid_file" ]]; then
  read -r pid < "$pid_file" || true
fi
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
  exit 1
fi
exit 0
