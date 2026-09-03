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

log_file="$(qs_runtime_file "quickshell-utility-ocr.log")"
anonymize="0"
ocr_lang="${UTILITY_HUB_OCR_LANG:-eng+por}"
tmp_file="$(mktemp "$(qs_runtime_root)/utility-hub-ocr-XXXXXX.png")"
trap 'rm -f "$tmp_file"' EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --anonymize)
            anonymize="1"
            shift
            ;;
        --lang)
            ocr_lang="${2:-eng+por}"
            shift 2
            ;;
        --self-test)
            command -v grim >/dev/null 2>&1 || { echo "missing grim"; exit 1; }
            command -v slurp >/dev/null 2>&1 || { echo "missing slurp"; exit 1; }
            command -v tesseract >/dev/null 2>&1 || { echo "missing tesseract"; exit 1; }
            command -v wl-copy >/dev/null 2>&1 || { echo "missing wl-copy"; exit 1; }
            echo "ok"
            exit 0
            ;;
        --list-langs)
            tesseract --list-langs 2>/dev/null | tail -n +2 || true
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! "$ocr_lang" =~ ^[a-zA-Z0-9+_-]+$ ]]; then
    notify-send -a "Utility Hub" "OCR" "Idioma inválido"
    printf 'ERROR: idioma OCR inválido (%s)\n' "$ocr_lang" >&2
    exit 1
fi

rotate_log() {
    local max_lines=300
    [[ -f "$log_file" ]] || return 0
    local line_count
    line_count="$(wc -l < "$log_file" 2>/dev/null || echo 0)"
    if (( line_count > max_lines )); then
        tail -n "$max_lines" "$log_file" > "${log_file}.tmp" 2>/dev/null || true
        mv -f "${log_file}.tmp" "$log_file" 2>/dev/null || true
    fi
}

get_slurp_args() {
    local -a args=("-f" "%x,%y %wx%h")
    local colors_file="${MATUGEN_COLORS_FILE:-$HOME/.cache/quickshell/matugen/colors.json}"
    if [[ -f "$colors_file" ]] && command -v jq >/dev/null 2>&1; then
        local accent bg
        accent="$(jq -r '.colors.primary // .colors.accent // empty' "$colors_file" 2>/dev/null || true)"
        bg="$(jq -r '.colors.surface // .colors.background // empty' "$colors_file" 2>/dev/null || true)"
        if [[ -n "$accent" ]]; then
            local raw_accent="${accent#\#}"
            local raw_bg="${bg#\#}"
            [[ -z "$raw_bg" ]] && raw_bg="11111b"
            args+=("-b" "#${raw_bg}66" "-c" "#${raw_accent}ff" "-s" "#${raw_accent}22" "-B" "#${raw_accent}88" "-w" "2")
        fi
    fi
    printf '%s\n' "${args[@]}"
}

touch "$log_file"
rotate_log

local_slurp_opts=()
mapfile -t local_slurp_opts < <(get_slurp_args)
geometry="$(slurp "${local_slurp_opts[@]}" 2>>"$log_file" || true)"
if [[ -z "$geometry" ]]; then
    notify-send -a "Utility Hub" "OCR" "Seleção cancelada"
    exit 0
fi

if ! grim -g "$geometry" "$tmp_file" 2>>"$log_file"; then
    notify-send -a "Utility Hub" "OCR" "Falha ao capturar região"
    printf 'ERROR: falha ao capturar região\n' >&2
    exit 1
fi

# Optional image contrast enhancement for cleaner OCR
if command -v convert >/dev/null 2>&1; then
    convert "$tmp_file" -colorspace Gray -contrast-stretch 0 "$tmp_file" 2>>"$log_file" || true
fi

# Extract text using tesseract
text="$(tesseract "$tmp_file" stdout -l "$ocr_lang" 2>>"$log_file" || true)"

# Filter and clean up output
text="$(printf '%s' "$text" | sed -e 's/[[:space:]]\+$//' -e '/^[[:space:]]*$/d')"

if [[ -z "${text// }" ]]; then
    notify-send -a "Utility Hub" "OCR" "Nenhum texto detectado"
    exit 0
fi

# Apply Anonymization / Redaction of Sensitive Data if requested
if [[ "$anonymize" == "1" ]]; then
    text="$(python3 - <<'PY' "$text"
import sys, re
raw = sys.argv[1]
# Mask Emails
raw = re.sub(r'[\w\.-]+@[\w\.-]+\.\w+', '[EMAIL]', raw)
# Mask IPv4 addresses
raw = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP_ADDRESS]', raw)
# Mask Credit Card Numbers (13-19 digits with spaces/dashes)
raw = re.sub(r'\b(?:\d[ -]*?){13,16}\b', '[CARD_NUMBER]', raw)
# Mask CPF / Brazilian ID formats
raw = re.sub(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b', '[CPF]', raw)
# Mask Phone Numbers
raw = re.sub(r'\b(?:\+?55\s?)?(?:\(?\d{2}\)?\s?)?\d{4,5}[-\s]?\d{4}\b', '[PHONE]', raw)
sys.stdout.write(raw)
PY
)"
fi

printf '%s' "$text" | wl-copy
char_count="$(printf '%s' "$text" | wc -m)"
preview="$(printf '%s' "$text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-45)"

if [[ "$anonymize" == "1" ]]; then
    notify-send -a "Utility Hub" "Texto Copiado (Anonimizado • ${char_count} chars)" "${preview}..."
else
    notify-send -a "Utility Hub" "Texto Copiado (${char_count} chars)" "${preview}..."
fi

printf '%s\n' "$text"
