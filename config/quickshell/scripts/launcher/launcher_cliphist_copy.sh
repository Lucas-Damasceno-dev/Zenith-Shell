#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    command -v cliphist >/dev/null 2>&1 || exit 1
    command -v wl-copy >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

entry_id="${1:-}"
[[ -n "$entry_id" ]] || exit 0

tmp_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
mkdir -p "$tmp_dir"
chmod 0700 "$tmp_dir" 2>/dev/null || true
tmp_file="$(mktemp "${tmp_dir}/cliphist-XXXXXX")"
chmod 0600 "$tmp_file"
trap 'rm -f "$tmp_file"' EXIT

cliphist decode "$entry_id" > "$tmp_file" 2>/dev/null || exit 0
if command -v file >/dev/null 2>&1; then
    image_mime="$(file -b --mime-type "$tmp_file" 2>/dev/null || echo text/plain)"
else
    meta_line="$(cliphist list | awk -F'\t' -v id="$entry_id" '$1 == id { print $2; exit }')"
    image_mime="$(printf '%s\n' "$meta_line" | sed -n 's/.*\(image\/[A-Za-z0-9.+-]*\).*/\1/p')"
fi

if [[ "$image_mime" == image/* ]]; then
    wl-copy --type "$image_mime" < "$tmp_file"
else
    wl-copy < "$tmp_file"
fi
