#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

if [[ "${1:-}" == "--self-test" ]]; then
  echo "ok"
  exit 0
fi

metrics_file="$(qs_state_file 'quickshell-focus-metrics.json')"
cat "$metrics_file" 2>/dev/null || echo '{}'
