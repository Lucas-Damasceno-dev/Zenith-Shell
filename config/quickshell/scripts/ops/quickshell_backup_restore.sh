#!/usr/bin/env bash
set -euo pipefail

mode="${1:-backup}"
archive_path="${2:-}"
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/backups"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
mkdir -p "$backup_dir"

if [[ "$mode" == "--self-test" ]]; then
  command -v tar >/dev/null 2>&1 || { echo "missing tar"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "missing install"; exit 1; }
  echo "ok"
  exit 0
fi

files=(
  "config.json"
  "weather-config.json"
  "notifications-history.json"
)

backup() {
  ts="$(date +%Y%m%d-%H%M%S)"
  out="$backup_dir/quickshell-config-$ts.tar.gz"
  existing=()
  for f in "${files[@]}"; do
    [[ -f "$config_dir/$f" ]] && existing+=("$f")
  done
  if [[ ${#existing[@]} -eq 0 ]]; then
    echo "no config files to backup"
    exit 1
  fi
  tar -czf "$out" -C "$config_dir" "${existing[@]}"
  echo "$out"
}

restore() {
  if [[ -z "$archive_path" || ! -f "$archive_path" ]]; then
    echo "usage: $0 restore /path/to/archive.tar.gz"
    exit 1
  fi
  local tmp_dir
  tmp_dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/quickshell-restore-XXXXXX")"
  trap 'rm -rf "$tmp_dir"' RETURN
  tar -xzf "$archive_path" -C "$tmp_dir"
  mkdir -p "$config_dir"
  for f in "${files[@]}"; do
    local candidate="$tmp_dir/$f"
    local legacy_candidate="$tmp_dir/${config_dir#/}/$f"
    if [[ -f "$candidate" ]]; then
      install -m 600 "$candidate" "$config_dir/$f"
    elif [[ -f "$legacy_candidate" ]]; then
      install -m 600 "$legacy_candidate" "$config_dir/$f"
    fi
  done
  echo "restored from $archive_path"
}

case "$mode" in
  backup) backup ;;
  restore) restore ;;
  *) echo "usage: $0 [backup|restore] [archive]"; exit 1 ;;
esac
