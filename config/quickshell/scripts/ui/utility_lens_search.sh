#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs
qs_detect_wayland_display

log_file="$(qs_runtime_file "quickshell-utility-lens.log")"
tmp_file="$(mktemp "$(qs_runtime_root)/utility-hub-lens-XXXXXX.png")"
trap 'rm -f "$tmp_file"' EXIT
confirm_upload="0"
anonymize="0"
provider="${UTILITY_HUB_LENS_PROVIDER:-google}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --confirm)
            confirm_upload="1"
            shift
            ;;
        --anonymize)
            anonymize="1"
            shift
            ;;
        --provider)
            provider="${2:-google}"
            shift 2
            ;;
        --self-test)
            command -v grim >/dev/null 2>&1 || { echo "missing grim"; exit 1; }
            command -v slurp >/dev/null 2>&1 || { echo "missing slurp"; exit 1; }
            command -v curl >/dev/null 2>&1 || { echo "missing curl"; exit 1; }
            command -v xdg-open >/dev/null 2>&1 || { echo "missing xdg-open"; exit 1; }
            echo "ok"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$provider" != "google" && "$provider" != "yandex" && "$provider" != "bing" ]]; then
    provider="google"
fi

rotate_log() {
    local max_lines=400
    [[ -f "$log_file" ]] || return 0
    local line_count
    line_count="$(wc -l < "$log_file" 2>/dev/null || echo 0)"
    if (( line_count > max_lines )); then
        tail -n "$max_lines" "$log_file" > "${log_file}.tmp" 2>/dev/null || true
        mv -f "${log_file}.tmp" "$log_file" 2>/dev/null || true
    fi
}

touch "$log_file"
rotate_log

if [[ "$confirm_upload" != "1" ]]; then
    notify-send -a "Utility Hub" "Google Lens" "Confirme o upload antes de enviar para terceiros"
    exit 0
fi

geometry="$(slurp 2>/dev/null || true)"
if [[ -z "$geometry" ]]; then
    notify-send -a "Utility Hub" "Google Lens" "Seleção cancelada"
    exit 0
fi

if ! grim -g "$geometry" "$tmp_file" 2>>"$log_file"; then
    notify-send -a "Utility Hub" "Google Lens" "Falha ao capturar região"
    printf 'ERROR: falha ao capturar região\n' >&2
    exit 1
fi

if [[ "$anonymize" == "1" ]]; then
    if command -v convert >/dev/null 2>&1; then
        convert "$tmp_file" -blur 0x9 "$tmp_file" 2>>"$log_file" || true
    fi
fi

uploaded_url="$(curl -fsS \
    --retry 3 \
    --retry-delay 1 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 40 \
    -F "file=@${tmp_file};type=image/png" \
    https://0x0.st 2>>"$log_file" || true)"
uploaded_url="$(printf '%s' "$uploaded_url" | tr -d '\r\n')"
if [[ -z "$uploaded_url" ]]; then
    notify-send -a "Utility Hub" "Google Lens" "Falha no upload temporário"
    printf 'ERROR: upload temporário falhou\n' >&2
    exit 1
fi

if command -v jq >/dev/null 2>&1; then
    encoded_url="$(jq -rn --arg u "$uploaded_url" '$u|@uri')"
else
    encoded_url="${uploaded_url//:/%3A}"
    encoded_url="${encoded_url//\//%2F}"
fi

target_url="https://lens.google.com/uploadbyurl?url=${encoded_url}"
if [[ "$provider" == "yandex" ]]; then
    target_url="https://yandex.com/images/search?rpt=imageview&url=${encoded_url}"
elif [[ "$provider" == "bing" ]]; then
    target_url="https://www.bing.com/images/search?q=imgurl:${encoded_url}&view=detailv2&iss=sbi"
fi

if ! xdg-open "$target_url" >/dev/null 2>&1; then
    notify-send -a "Utility Hub" "Google Lens" "Falha ao abrir navegador"
    printf 'ERROR: falha ao abrir navegador\n' >&2
    exit 1
fi

notify-send -a "Utility Hub" "Google Lens" "Pesquisa visual aberta no navegador (${provider})"
