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

mode="${1:-full}"
shift || true

log_file="$(qs_runtime_file "quickshell-utility-screenshot.log")"
history_file="$(qs_state_file "utility-hub-capture-history")"
history_lock="$(qs_runtime_file "utility-hub-capture-history.lock")"
default_dir="${HOME}/Pictures/Screenshots"
save_dir="${UTILITY_HUB_SCREENSHOT_DIR:-$default_dir}"
format="${UTILITY_HUB_SCREENSHOT_FORMAT:-png}"
template="${UTILITY_HUB_FILE_TEMPLATE:-screenshot_{timestamp}}"
quality="${UTILITY_HUB_SCREENSHOT_QUALITY:-92}"
copy_path_thumb="0"
annotate_capture="0"
delay_sec=0
target_output=""

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

fail() {
    local msg="$1"
    printf '[%s] ERROR %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$msg" >> "$log_file"
    printf 'ERROR: %s\n' "$msg" >&2
    notify-send -a "Utility Hub" "Falha no screenshot" "$msg"
    exit 1
}

if [[ "$mode" == "--self-test" ]]; then
    command -v grim >/dev/null 2>&1 || { echo "missing grim"; exit 1; }
    command -v slurp >/dev/null 2>&1 || { echo "missing slurp"; exit 1; }
    command -v wl-copy >/dev/null 2>&1 || { echo "missing wl-copy"; exit 1; }
    echo "ok"
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            format="${2:-png}"
            shift 2
            ;;
        --dest)
            save_dir="${2:-$default_dir}"
            shift 2
            ;;
        --template)
            template="${2:-screenshot_{timestamp}}"
            shift 2
            ;;
        --copy-path-thumb)
            copy_path_thumb="1"
            shift
            ;;
        --annotate)
            annotate_capture="1"
            shift
            ;;
        --delay)
            delay_sec="${2:-0}"
            shift 2
            ;;
        --output)
            target_output="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$mode" == "annotate" ]]; then
    mode="region"
    annotate_capture="1"
fi

if [[ "$mode" != "full" && "$mode" != "all" && "$mode" != "window" && "$mode" != "region" && "$mode" != "monitor" && "$mode" != "screen" && "$mode" != "focused" ]]; then
    fail "Modo inválido: $mode"
fi

case "${format,,}" in
    png) out_ext="png" ;;
    jpg|jpeg) out_ext="jpg" ;;
    webp) out_ext="webp" ;;
    *) fail "Formato inválido: $format" ;;
esac

if [[ "${save_dir:0:1}" != "/" ]]; then
    save_dir="${HOME}/${save_dir#./}"
fi

mkdir -p "$save_dir" || fail "Não foi possível criar destino: $save_dir"
touch "$log_file"
rotate_log

if [[ ! "$delay_sec" =~ ^[0-9]+$ ]]; then
    delay_sec=0
fi
if (( delay_sec > 0 )); then
    sleep "$delay_sec"
fi

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
safe_template="${template//\{timestamp\}/$timestamp}"
safe_template="${safe_template//\{type\}/screenshot}"
safe_template="${safe_template//\{mode\}/$mode}"
safe_template="$(printf '%s' "$safe_template" | tr -cs 'A-Za-z0-9._-' '_')"
safe_template="${safe_template#_}"
safe_template="${safe_template%_}"
[[ -n "$safe_template" ]] || safe_template="screenshot_${timestamp}"

output_file="${save_dir}/${safe_template}.${out_ext}"
tmp_capture="$(mktemp "$(qs_runtime_root)/utility-hub-shot-XXXXXX.png")"
trap 'rm -f "$tmp_capture"' EXIT

capture_all() {
    grim "$tmp_capture" 2>>"$log_file"
}

capture_focused() {
    local mon=""
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        mon="$(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused==true)][0].name // empty')"
    fi
    if [[ -n "$mon" ]]; then
        grim -o "$mon" "$tmp_capture" 2>>"$log_file"
    else
        grim "$tmp_capture" 2>>"$log_file"
    fi
}

capture_screen_picker() {
    if [[ -n "$target_output" ]]; then
        grim -o "$target_output" "$tmp_capture" 2>>"$log_file"
        return $?
    fi

    # Check number of connected monitors
    local count=1
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        count="$(hyprctl monitors -j 2>/dev/null | jq -r 'length // 1')"
    fi

    if (( count > 1 )) && command -v slurp >/dev/null 2>&1; then
        local geometry
        geometry="$(slurp -o -b '#00000044' -c '#89b4faff' -s '#89b4fa22' -w 2 -f '%x,%y %wx%h' 2>>"$log_file")" || {
            local slurp_exit=$?
            [[ "$slurp_exit" -eq 1 ]] && return 2
            return "$slurp_exit"
        }
        if [[ -n "$geometry" ]]; then
            grim -g "$geometry" "$tmp_capture" 2>>"$log_file"
            return $?
        fi
    fi

    capture_focused
}

capture_window() {
    local geometry=""
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        geometry="$(hyprctl clients -j 2>/dev/null | jq -r '
            [.[] | select(.focusHistoryID == 0 and .mapped == true and .hidden == false)][0] |
            if (.at|type=="array") and (.size|type=="array") and (.at|length)>=2 and (.size|length)>=2 then
                "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
            else empty
            end
        ' 2>/dev/null || true)"

        if [[ -z "$geometry" ]]; then
            geometry="$(hyprctl activewindow -j 2>/dev/null | jq -r '
                if (.at|type=="array") and (.size|type=="array") and (.at|length)>=2 and (.size|length)>=2 then
                    "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
                else empty
                end
            ' 2>/dev/null || true)"
        fi
    fi

    if [[ -n "$geometry" ]]; then
        grim -g "$geometry" "$tmp_capture" 2>>"$log_file"
    else
        capture_region
    fi
}

capture_region() {
    local geometry
    geometry="$(slurp -d -b '#00000044' -c '#89b4faff' -s '#89b4fa22' -w 2 -f '%x,%y %wx%h' 2>>"$log_file")" || {
        local slurp_exit=$?
        printf '[%s] slurp exited with code %d\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$slurp_exit" >> "$log_file"
        [[ "$slurp_exit" -eq 1 ]] && return 2
        return "$slurp_exit"
    }

    if [[ -z "$geometry" ]]; then
        return 2
    fi

    grim -g "$geometry" "$tmp_capture" 2>>"$log_file"
}

capture_status=0
case "$mode" in
    all|full) capture_all || capture_status=$? ;;
    screen|monitor) capture_screen_picker || capture_status=$? ;;
    focused) capture_focused || capture_status=$? ;;
    window) capture_window || capture_status=$? ;;
    region) capture_region || capture_status=$? ;;
esac

if [[ "$capture_status" -eq 2 ]]; then
    exit 0
fi
if [[ "$capture_status" -ne 0 || ! -s "$tmp_capture" ]]; then
    fail "Capture inválida (wayland/seleção)"
fi

if [[ "$out_ext" == "png" ]]; then
    mv "$tmp_capture" "$output_file"
    tmp_capture=""
else
    if command -v magick >/dev/null 2>&1; then
        magick "$tmp_capture" -quality "$quality" "$output_file" 2>>"$log_file" || fail "Falha convertendo para ${out_ext}"
    elif command -v convert >/dev/null 2>&1; then
        convert "$tmp_capture" -quality "$quality" "$output_file" 2>>"$log_file" || fail "Falha convertendo para ${out_ext}"
    elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -i "$tmp_capture" -q:v 2 "$output_file" 2>>"$log_file" || fail "Falha convertendo para ${out_ext}"
    else
        fail "Conversor de imagem não encontrado (magick/convert/ffmpeg)"
    fi
fi

[[ -s "$output_file" ]] || fail "Arquivo final inválido"

if [[ "$annotate_capture" == "1" ]] && command -v swappy >/dev/null 2>&1; then
    swappy -f "$output_file" >/dev/null 2>&1 &
fi

wl-copy < "$output_file" >/dev/null 2>&1 || true
printf '%s\n' "$output_file" > "$(qs_runtime_file "utility-hub-last-path")"

if [[ "$copy_path_thumb" == "1" ]]; then
    thumb_file="$(qs_runtime_file "utility-hub-last-thumb.png")"
    if command -v magick >/dev/null 2>&1; then
        magick "$output_file" -thumbnail 360x200 "$thumb_file" 2>>"$log_file" || true
    elif command -v convert >/dev/null 2>&1; then
        convert "$output_file" -thumbnail 360x200 "$thumb_file" 2>>"$log_file" || true
    fi
    [[ -f "$thumb_file" ]] && wl-copy < "$thumb_file" >/dev/null 2>&1 || true
    printf '%s\n' "$thumb_file" > "$(qs_runtime_file "utility-hub-last-thumb")"
    printf '%s\n' "$output_file" | wl-copy --primary >/dev/null 2>&1 || true
fi

if command -v flock >/dev/null 2>&1; then
    {
        flock -x 9 || true
        printf '%s\t%s\tscreenshot\n' "$(date +%s)" "$output_file" >> "$history_file"
        tail -n 60 "$history_file" > "${history_file}.tmp" 2>/dev/null || true
        mv -f "${history_file}.tmp" "$history_file" 2>/dev/null || true
    } 9>"$history_lock" || true
else
    printf '%s\t%s\tscreenshot\n' "$(date +%s)" "$output_file" >> "$history_file" 2>/dev/null || true
fi

summary="Screenshot salva"
body="$(basename "$output_file")"
if [[ "$annotate_capture" == "1" ]]; then
    body="${body} (anotar)"
fi

# Send desktop notification with image preview icon and interactive buttons
if notify-send --help 2>/dev/null | grep -q -- '--action'; then
    (
        action="$(notify-send -a "Utility Hub" -i "$output_file" -w \
            -A edit="Editar" \
            -A folder="Abrir Pasta" \
            -A delete="Apagar" \
            "$summary" "$body" 2>/dev/null || true)"
        case "$action" in
            edit)
                command -v swappy >/dev/null 2>&1 && swappy -f "$output_file" >/dev/null 2>&1 &
                ;;
            folder)
                command -v xdg-open >/dev/null 2>&1 && xdg-open "$(dirname "$output_file")" >/dev/null 2>&1 &
                ;;
            delete)
                rm -f "$output_file"
                notify-send -a "Utility Hub" "Screenshot removida" "$(basename "$output_file")"
                ;;
        esac
    ) >/dev/null 2>&1 &
else
    notify-send -a "Utility Hub" -i "$output_file" "$summary" "$body" || true
fi

printf '%s\n' "$output_file"
