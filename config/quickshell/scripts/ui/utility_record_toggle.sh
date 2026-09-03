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

pid_file="$(qs_runtime_file "utility-hub-rec.pid")"
# shellcheck disable=SC2034
state_file="$(qs_runtime_file "utility-hub-rec.state")"
history_file="$(qs_state_file "utility-hub-capture-history")"
log_file="$(qs_runtime_file "quickshell-utility-record.log")"
state_lock_file="$(qs_runtime_file "utility-hub-rec.lock")"
history_lock_file="$(qs_runtime_file "utility-hub-capture-history.lock")"
default_output_dir="${HOME}/Videos/ScreenRecords"
output_dir="${UTILITY_HUB_VIDEO_DIR:-$default_output_dir}"

container="${UTILITY_HUB_VIDEO_CONTAINER:-mkv}"
# shellcheck disable=SC2034
codec="${UTILITY_HUB_VIDEO_CODEC:-auto}"
fps="${UTILITY_HUB_VIDEO_FPS:-30}"
quality="${UTILITY_HUB_VIDEO_QUALITY:-23}"
# shellcheck disable=SC2034
template="${UTILITY_HUB_FILE_TEMPLATE:-recording_{timestamp}}"

mkdir -p "$output_dir"
touch "$log_file"

rotate_log() {
    local max_lines=500
    local line_count
    line_count="$(wc -l < "$log_file" 2>/dev/null || echo 0)"
    if (( line_count > max_lines )); then
        tail -n "$max_lines" "$log_file" > "${log_file}.tmp" 2>/dev/null || true
        mv -f "${log_file}.tmp" "$log_file" 2>/dev/null || true
    fi
}
rotate_log

command="${1:-status}"
shift || true

if [[ "$command" == "--self-test" ]]; then
    command -v wf-recorder >/dev/null 2>&1 || { echo "missing wf-recorder"; exit 1; }
    command -v slurp >/dev/null 2>&1 || { echo "missing slurp"; exit 1; }
    echo "ok"
    exit 0
fi

mic_flag="0"
system_flag="0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mic)
            mic_flag="${2:-0}"
            shift 2
            ;;
        --system)
            system_flag="${2:-0}"
            shift 2
            ;;
        --container)
            container="${2:-mkv}"
            shift 2
            ;;
        --codec)
            # shellcheck disable=SC2034
            codec="${2:-auto}"
            shift 2
            ;;
        --fps)
            fps="${2:-30}"
            shift 2
            ;;
        --quality)
            quality="${2:-23}"
            shift 2
            ;;
        --dest)
            output_dir="${2:-$default_output_dir}"
            shift 2
            ;;
        --template)
            # shellcheck disable=SC2034
            template="${2:-recording_{timestamp}}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "${output_dir:0:1}" != "/" ]]; then
    output_dir="${HOME}/${output_dir#./}"
fi
mkdir -p "$output_dir"

container="$(printf '%s' "$container" | tr '[:upper:]' '[:lower:]')"
case "$container" in
    mkv|mp4|gif|webm) ;;
    *) container="mkv" ;;
esac

if [[ ! "$fps" =~ ^[0-9]+$ ]] || [[ "$fps" -lt 10 || "$fps" -gt 144 ]]; then
    fps="30"
fi

if [[ ! "$quality" =~ ^[0-9]+$ ]] || [[ "$quality" -lt 1 || "$quality" -gt 40 ]]; then
    quality="23"
fi

log_msg() {
    printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$log_file"
}

# shellcheck source=../lib/utility_record_helpers.sh
source "$script_dir/../lib/utility_record_helpers.sh"
state_mode=""
state_file_path=""
state_mic="0"
state_system="0"
state_started="0"
state_container="mkv"
state_paused="0"

print_status() {
    read_state
    local running="0"
    local pid=""
    local now duration
    now="$(date +%s)"
    duration=0

    if is_running; then
        running="1"
        pid="$(current_pid)"
        if [[ "$state_started" =~ ^[0-9]+$ ]] && [[ "$state_started" -gt 0 ]]; then
            duration=$(( now - state_started ))
        fi
    else
        flock -x "$state_lock_file" -c "rm -f '$pid_file'"
    fi

    printf 'running=%s\n' "$running"
    printf 'pid=%s\n' "$pid"
    printf 'mode=%s\n' "$state_mode"
    printf 'file=%s\n' "$state_file_path"
    printf 'mic=%s\n' "$state_mic"
    printf 'system=%s\n' "$state_system"
    printf 'started=%s\n' "$state_started"
    printf 'duration=%s\n' "$duration"
    printf 'container=%s\n' "$state_container"
    printf 'paused=%s\n' "${state_paused:-0}"
}

start_recording() {
    local mode="$1"

    if is_running; then
        print_status
        return 0
    fi

    local output_file
    output_file="$(build_filename "$mode")"

    local -a args
    args=(-f "$output_file" -r "$fps")

    if [[ "$mode" == "region" ]]; then
        local geometry
        geometry="$(slurp -f '%x,%y %wx%h' 2>>"$log_file")" || {
            local slurp_exit=$?
            log_msg "slurp exited with code $slurp_exit"
            if [[ "$slurp_exit" -eq 1 ]]; then
                notify-send -a "Utility Hub" "Gravação cancelada" "Nenhuma região selecionada"
                print_status
                return 0
            fi
            notify-send -a "Utility Hub" "Falha na seleção" "slurp falhou com código $slurp_exit"
            print_status
            return 1
        }

        if [[ -z "$geometry" ]]; then
            log_msg "slurp returned empty geometry"
            notify-send -a "Utility Hub" "Gravação cancelada" "Nenhuma região selecionada"
            print_status
            return 0
        fi

        log_msg "slurp geometry: $geometry"
        args+=(-g "$geometry")
    fi

    append_codec_and_quality_args args

    if [[ "$container" != "gif" ]]; then
        append_audio_args args
    fi

    log_msg "Starting wf-recorder: ${args[*]}"
    wf-recorder "${args[@]}" >>"$log_file" 2>&1 &
    local pid=$!

    sleep 0.2
    if ! pid_is_wf_recorder "$pid"; then
        flock -x "$state_lock_file" -c "rm -f '$pid_file'"
        notify-send -a "Utility Hub" "Falha ao iniciar gravação" "Verifique wf-recorder/permissões"
        printf 'ERROR: wf-recorder falhou ao iniciar\n' >&2
        log_msg "wf-recorder failed to start (pid=$pid)"
        print_status
        return 1
    fi

    {
        flock -x 9
        printf '%s\n' "$pid" > "$pid_file"
    } 9>"$state_lock_file"
    write_state "$mode" "$output_file" "$mic_flag" "$system_flag" "$(date +%s)" "$container" "0"
    notify-send -a "Utility Hub" "Gravação iniciada" "$(basename "$output_file")"
    print_status
}

pause_recording() {
    local pid
    if ! pid="$(current_pid)"; then
        print_status
        return 0
    fi
    read_state
    if [[ "$state_paused" == "1" ]]; then
        kill -CONT "$pid" 2>/dev/null || true
        write_state "$state_mode" "$state_file_path" "$state_mic" "$state_system" "$state_started" "$state_container" "0"
        notify-send -a "Utility Hub" "Gravação retomada" "$(basename "$state_file_path")"
    else
        kill -STOP "$pid" 2>/dev/null || true
        write_state "$state_mode" "$state_file_path" "$state_mic" "$state_system" "$state_started" "$state_container" "1"
        notify-send -a "Utility Hub" "Gravação pausada" "$(basename "$state_file_path")"
    fi
    print_status
}

stop_recording() {
    local pid
    if ! pid="$(current_pid)"; then
        flock -x "$state_lock_file" -c "rm -f '$pid_file'"
        print_status
        return 0
    fi

    read_state
    log_msg "Stopping wf-recorder pid=$pid"

    kill -INT "$pid" 2>/dev/null || true
    if ! wait_for_exit "$pid" 30 0.1; then
        log_msg "wf-recorder pid=$pid did not exit after SIGINT; sending SIGTERM"
        kill -TERM "$pid" 2>/dev/null || true
    fi
    if ! wait_for_exit "$pid" 20 0.1; then
        log_msg "wf-recorder pid=$pid still alive after SIGTERM; sending SIGKILL"
        kill -9 "$pid" 2>/dev/null || true
    fi
    if ! wait_for_exit "$pid" 10 0.1; then
        notify-send -a "Utility Hub" "Erro ao parar gravação" "Processo travado: $pid"
        printf 'ERROR: processo wf-recorder travado (%s)\n' "$pid" >&2
        log_msg "Failed to stop wf-recorder pid=$pid after SIGKILL"
        return 1
    fi

    {
        flock -x 9
        rm -f "$pid_file"
    } 9>"$state_lock_file"

    local recorded_file="${state_file_path:-}"
    if [[ -n "$recorded_file" && -f "$recorded_file" ]]; then
        {
            flock -x 9
            printf '%s\t%s\tvideo\n' "$(date +%s)" "$recorded_file" >> "$history_file"
            tail -n 60 "$history_file" > "${history_file}.tmp" 2>/dev/null || true
            mv -f "${history_file}.tmp" "$history_file" 2>/dev/null || true
        } 9>"$history_lock_file"

        # Notification with interactive actions
        if notify-send --help 2>/dev/null | grep -q -- '--action'; then
            (
                action="$(notify-send -a "Utility Hub" -w \
                    -A play="Reproduzir" \
                    -A folder="Abrir Pasta" \
                    -A delete="Apagar" \
                    "Gravação finalizada" "$(basename "$recorded_file")" 2>/dev/null || true)"
                case "$action" in
                    play)
                        command -v xdg-open >/dev/null 2>&1 && xdg-open "$recorded_file" >/dev/null 2>&1 &
                        ;;
                    folder)
                        command -v xdg-open >/dev/null 2>&1 && xdg-open "$(dirname "$recorded_file")" >/dev/null 2>&1 &
                        ;;
                    delete)
                        rm -f "$recorded_file"
                        notify-send -a "Utility Hub" "Gravação removida" "$(basename "$recorded_file")"
                        ;;
                esac
            ) >/dev/null 2>&1 &
        else
            notify-send -a "Utility Hub" "Gravação finalizada" "$(basename "$recorded_file")" || true
        fi
    else
        notify-send -a "Utility Hub" "Gravação finalizada" "Arquivo salvo com sucesso" || true
    fi

    print_status
}

case "$command" in
    status)
        print_status
        ;;
    start-full)
        start_recording "full"
        ;;
    start-region)
        start_recording "region"
        ;;
    start-gif)
        container="gif"
        start_recording "region"
        ;;
    pause|toggle-pause)
        pause_recording
        ;;
    stop)
        stop_recording
        ;;
    toggle-full)
        if is_running; then stop_recording; else start_recording "full"; fi
        ;;
    toggle-region)
        if is_running; then stop_recording; else start_recording "region"; fi
        ;;
    toggle-gif)
        if is_running; then stop_recording; else container="gif"; start_recording "region"; fi
        ;;
    *)
        notify-send -a "Utility Hub" "Comando inválido" "$command"
        printf 'ERROR: comando inválido %s\n' "$command" >&2
        exit 1
        ;;
esac
