#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v cliphist >/dev/null 2>&1 || exit 1
  echo "ok"
  exit 0
fi

entry_id="${1:-}"
[[ -n "$entry_id" ]] || exit 0

cache_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/cliphist-preview"
mkdir -p "$cache_dir"

tmp_file="$(mktemp "${cache_dir}/.${entry_id}.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

cliphist decode "$entry_id" > "$tmp_file" 2>/dev/null || exit 0
if command -v file >/dev/null 2>&1; then
  mime="$(file -b --mime-type "$tmp_file" 2>/dev/null || echo application/octet-stream)"
else
  meta_line="$(cliphist list | awk -F'\t' -v id="$entry_id" '$1 == id { print $2; exit }')"
  mime="$(printf '%s\n' "$meta_line" | sed -n 's/.*\(image\/[A-Za-z0-9.+-]*\).*/\1/p')"
fi

case "$mime" in
  image/png) ext="png" ;;
  image/jpeg) ext="jpg" ;;
  image/gif) ext="gif" ;;
  image/webp) ext="webp" ;;
  image/bmp) ext="bmp" ;;
  image/svg+xml) ext="svg" ;;
  image/*) ext="img" ;;
  *) exit 0 ;;
esac

out_file="${cache_dir}/${entry_id}.${ext}"
mv "$tmp_file" "$out_file"
trap - EXIT
printf '%s\n' "$out_file"
