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

state_file="$(qs_state_file "utility-hub-last-color")"
history_file="$(qs_state_file "utility-hub-color-history")"
log_file="$(qs_runtime_file "quickshell-utility-color.log")"
history_lock="$(qs_runtime_file "utility-hub-color-history.lock")"

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

hex_to_rgb() {
    local hex="${1#\#}"
    local r g b
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    printf 'rgb(%s,%s,%s)\n' "$r" "$g" "$b"
}

hex_to_hsl() {
    python3 - "$1" <<'PY'
import colorsys, sys
hexv = sys.argv[1].lstrip("#")
r = int(hexv[0:2], 16) / 255.0
g = int(hexv[2:4], 16) / 255.0
b = int(hexv[4:6], 16) / 255.0
h, l, s = colorsys.rgb_to_hls(r, g, b)
print(f"hsl({round(h*360)},{round(s*100)}%,{round(l*100)}%)")
PY
}

latest_entry() {
    if [[ -f "$history_file" ]]; then
        tail -n 1 "$history_file"
    elif [[ -f "$state_file" ]]; then
        local hex
        hex="$(cat "$state_file" 2>/dev/null || true)"
        if [[ -n "$hex" ]]; then
            local rgb hsl
            rgb="$(hex_to_rgb "$hex")"
            hsl="$(hex_to_hsl "$hex")"
            printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$hex" "$rgb" "$hsl"
        fi
    fi
}

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprpicker >/dev/null 2>&1 || { echo "missing hyprpicker"; exit 1; }
    echo "ok"
    exit 0
fi

touch "$log_file"
rotate_log

case "${1:-pick}" in
    status)
        cat "$state_file" 2>/dev/null || true
        exit 0
        ;;
    history)
        if [[ -f "$history_file" ]]; then
            tail -n 5 "$history_file" | jq -R '
                select(length > 0)
                | split("\t")
                | { timestamp: .[0], hex: .[1], rgb: .[2], hsl: .[3] }
            ' | jq -s '.'
        else
            echo "[]"
        fi
        exit 0
        ;;
    copy-rgb|copy-hsl|copy-hex)
        entry="$(latest_entry || true)"
        [[ -n "${entry:-}" ]] || { echo ""; exit 0; }
        IFS=$'\t' read -r _ hex rgb hsl <<< "$entry"
        case "$1" in
            copy-rgb) out="$rgb" ;;
            copy-hsl) out="$hsl" ;;
            *) out="$hex" ;;
        esac
        printf '%s\n' "$out" | wl-copy >/dev/null 2>&1
        printf '%s\n' "$out"
        notify-send -a "Utility Hub" "Color Picker" "Copiado: $out"
        exit 0
        ;;
esac

if ! command -v hyprpicker >/dev/null 2>&1; then
    notify-send -a "Utility Hub" "Color Picker" "hyprpicker não encontrado"
    printf 'ERROR: hyprpicker não encontrado\n' >&2
    exit 1
fi

raw_color="$(hyprpicker -a 2>/dev/null | tail -n1 | tr -d '\r' || true)"
hex_color="$(printf '%s' "$raw_color" | grep -Eo '#?[0-9a-fA-F]{6}' | head -n1 || true)"

if [[ -z "$hex_color" ]]; then
    printf '[%s] no color captured\n' "$(date +%Y-%m-%dT%H:%M:%S)" >> "$log_file"
    notify-send -a "Utility Hub" "Color Picker" "Seleção cancelada"
    exit 0
fi

if [[ "$hex_color" != \#* ]]; then
    hex_color="#${hex_color}"
fi

hex_color="$(printf '%s' "$hex_color" | tr '[:lower:]' '[:upper:]')"
rgb_color="$(hex_to_rgb "$hex_color")"
hsl_color="$(hex_to_hsl "$hex_color")"

printf '%s\n' "$hex_color" > "$state_file"
{
    flock -x 9
    printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$hex_color" "$rgb_color" "$hsl_color" >> "$history_file"
    tail -n 40 "$history_file" > "${history_file}.tmp" 2>/dev/null || true
    mv -f "${history_file}.tmp" "$history_file" 2>/dev/null || true
} 9>"$history_lock"

printf '%s\n' "$hex_color" | wl-copy >/dev/null 2>&1
notify-send -a "Utility Hub" "Color Picker" "Cor copiada: $hex_color"
printf '%s\n' "$hex_color"
