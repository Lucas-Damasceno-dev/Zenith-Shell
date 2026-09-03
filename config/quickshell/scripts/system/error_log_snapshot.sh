#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

if [[ "${1:-}" == "--self-test" ]]; then
  command -v journalctl >/dev/null 2>&1 || { echo "missing journalctl"; exit 1; }
  echo "ok"
  exit 0
fi

runtime_dir="$(qs_runtime_root)"
state_dir="$(qs_state_root)"

printf '__LOG_BEGIN__\n'
printf '[quickshell]\n'
journalctl --user -u quickshell --since "-30 min" --no-pager -p warning -n 120 2>/dev/null | tail -n 40 || true

for dir in "$runtime_dir" "$state_dir" /tmp; do
  [[ -d "$dir" ]] || continue
  find "$dir" -maxdepth 1 -type f -mmin -30 \( -name 'quickshell-*.log' -o -name 'utility-hub-*.log' \) -print 2>/dev/null | sort | while IFS= read -r f; do
    printf '[%s]\n' "$f"
    tail -n 20 "$f" 2>/dev/null || true
  done
done
printf '__LOG_END__\n'
