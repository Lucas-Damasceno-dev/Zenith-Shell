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

logs_days="${1:-7}"
media_days="${2:-14}"
runtime_dir="$(qs_runtime_root)"
state_dir="$(qs_state_root)"
cache_dir="$(qs_cache_root)"

for dir in "$runtime_dir" "$state_dir" "$cache_dir"; do
  find "$dir" -maxdepth 1 -type f -name 'quickshell-*.log' -mtime +"$logs_days" -print -delete 2>/dev/null || true
  find "$dir" -maxdepth 1 -type f -name 'utility-hub-*' -mtime +"$logs_days" -print -delete 2>/dev/null || true
done

# Legacy cleanup compatibility
find /tmp -maxdepth 1 -type f -name 'quickshell-utility-*.log' -mtime +"$logs_days" -print -delete || true
find /tmp -maxdepth 1 -type f -name 'utility-hub-*' -mtime +"$logs_days" -print -delete || true

find "$HOME/Pictures/Screenshots" -type f -mtime +"$media_days" -print -delete 2>/dev/null || true
find "$HOME/Videos/ScreenRecords" -type f -mtime +"$media_days" -print -delete 2>/dev/null || true

echo "cleanup complete (logs>${logs_days}d, media>${media_days}d)"
