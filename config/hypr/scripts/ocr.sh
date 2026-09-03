#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v grim >/dev/null 2>&1 || exit 1
    command -v slurp >/dev/null 2>&1 || exit 1
    command -v tesseract >/dev/null 2>&1 || exit 1
    command -v wl-copy >/dev/null 2>&1 || exit 1
    command -v notify-send >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
tmp_dir="${runtime_dir}/quickshell-ocr"
mkdir -p "$tmp_dir"
tmp_file="$(mktemp "${tmp_dir}/ocr-snap-XXXXXX.png")"
tmp_prefix="${tmp_file%.png}"
trap 'rm -f "$tmp_file" "${tmp_prefix}.txt"' EXIT

selection="$(slurp 2>/dev/null || true)"
if [[ -z "$selection" ]]; then
    notify-send "OCR" "Seleção cancelada"
    exit 1
fi

grim -g "$selection" "$tmp_file"
tesseract "$tmp_file" "$tmp_prefix" -l eng+por >/dev/null 2>&1

if [[ ! -f "${tmp_prefix}.txt" ]]; then
    notify-send "OCR" "Falha ao extrair texto"
    exit 1
fi

tr '\n' ' ' < "${tmp_prefix}.txt" | wl-copy
notify-send "OCR" "Text extracted and copied!" -i "edit-copy"
