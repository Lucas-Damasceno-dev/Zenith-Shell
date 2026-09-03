#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

if [[ "${BASH_SOURCE[0]}" == "$0" && "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

read_state() {
    state_mode=""
    state_file_path=""
    state_mic="0"
    state_system="0"
    state_started="0"
    state_container="mkv"
    state_paused="0"

    if [[ -f "$state_file" ]]; then
        mapfile -t lines < "$state_file"
        state_mode="${lines[0]:-}"
        state_file_path="${lines[1]:-}"
        state_mic="${lines[2]:-0}"
        state_system="${lines[3]:-0}"
        state_started="${lines[4]:-0}"
        state_container="${lines[5]:-mkv}"
        state_paused="${lines[6]:-0}"
    fi
}

write_state() {
    local mode="$1"
    local file_path="$2"
    local mic="$3"
    local system="$4"
    local started="$5"
    local cont="$6"
    local paused="${7:-0}"
    {
        flock -x 9
        printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' "$mode" "$file_path" "$mic" "$system" "$started" "$cont" "$paused" > "$state_file"
    } 9>"$state_lock_file"
}

pid_from_file() {
    [[ -f "$pid_file" ]] || return 1
    local pid
    pid="$(
        flock -s "$state_lock_file" -c "cat '$pid_file' 2>/dev/null || true"
    )"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$pid"
}

pid_is_wf_recorder() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    local comm
    comm="$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
    [[ "$comm" == "wf-recorder" ]]
}

current_pid() {
    local pid
    pid="$(pid_from_file)" || return 1
    pid_is_wf_recorder "$pid" || return 1
    printf '%s\n' "$pid"
}

is_running() {
    current_pid >/dev/null 2>&1
}

wait_for_exit() {
    local pid="$1"
    local attempts="${2:-30}"
    local delay="${3:-0.1}"
    local i
    for ((i=0; i<attempts; i++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep "$delay"
    done
    return 1
}

resolve_mic_source() {
    if [[ -n "${UTILITY_HUB_MIC_AUDIO_DEVICE:-}" ]]; then
        printf '%s\n' "$UTILITY_HUB_MIC_AUDIO_DEVICE"
        return 0
    fi
    if command -v pactl >/dev/null 2>&1; then
        pactl get-default-source 2>/dev/null || true
    fi
}

resolve_system_source() {
    if [[ -n "${UTILITY_HUB_SYSTEM_AUDIO_DEVICE:-}" ]]; then
        printf '%s\n' "$UTILITY_HUB_SYSTEM_AUDIO_DEVICE"
        return 0
    fi
    if command -v pactl >/dev/null 2>&1; then
        local sink
        sink="$(pactl get-default-sink 2>/dev/null || true)"
        [[ -n "$sink" ]] && printf '%s.monitor\n' "$sink"
    fi
}

append_audio_args() {
    # shellcheck disable=SC2178
    local -n args_ref="$1"
    local mic_source=""
    local system_source=""

    if [[ "$mic_flag" == "1" ]]; then
        mic_source="$(resolve_mic_source | head -n1 | tr -d '\r' || true)"
    fi
    if [[ "$system_flag" == "1" ]]; then
        system_source="$(resolve_system_source | head -n1 | tr -d '\r' || true)"
    fi

    # Note: wf-recorder accepts a single --audio argument
    if [[ "$mic_flag" == "1" && "$system_flag" == "1" ]]; then
        # When both are active, prefer system audio or default audio loopback
        if [[ -n "$system_source" ]]; then
            args_ref+=(--audio="$system_source")
            log_msg "Using system audio source for mixed capture: $system_source"
        elif [[ -n "$mic_source" ]]; then
            args_ref+=(--audio="$mic_source")
            log_msg "Using mic source: $mic_source"
        else
            args_ref+=(--audio)
            log_msg "Using default audio"
        fi
    elif [[ "$mic_flag" == "1" && -n "$mic_source" ]]; then
        args_ref+=(--audio="$mic_source")
        log_msg "Using mic source: $mic_source"
    elif [[ "$system_flag" == "1" && -n "$system_source" ]]; then
        args_ref+=(--audio="$system_source")
        log_msg "Using system source: $system_source"
    elif [[ "$mic_flag" == "1" || "$system_flag" == "1" ]]; then
        args_ref+=(--audio)
        log_msg "Audio requested; using default wf-recorder --audio"
    fi
}

build_filename() {
    local mode="$1"
    local ts
    ts="$(date +%Y-%m-%d_%H-%M-%S)"
    local safe_template="${template//\{timestamp\}/$ts}"
    safe_template="${safe_template//\{type\}/recording}"
    safe_template="${safe_template//\{mode\}/$mode}"
    safe_template="$(printf '%s' "$safe_template" | tr -cs 'A-Za-z0-9._-' '_')"
    safe_template="${safe_template#_}"
    [[ -n "$safe_template" ]] || safe_template="recording_${ts}"
    printf '%s/%s.%s\n' "$output_dir" "$safe_template" "$container"
}

append_codec_and_quality_args() {
    # shellcheck disable=SC2178
    local -n args_ref="$1"
    local chosen_codec="$codec"

    # Hardware acceleration detection (VAAPI)
    if [[ "$chosen_codec" == "auto" ]]; then
        # On Intel Haswell and older drivers, scale_vaapi DMA-BUF filter graph fails in wf-recorder.
        # libx264 ultrafast provides rock-solid, zero-crash software encoding with <10% CPU usage.
        chosen_codec="libx264"
    elif [[ "$chosen_codec" == "vaapi" ]]; then
        chosen_codec="h264_vaapi"
    fi

    if [[ "$container" == "gif" ]]; then
        args_ref+=(-c gif -r "${fps:-15}")
        return 0
    fi

    case "$chosen_codec" in
        h264_vaapi|vaapi)
            args_ref+=(-c h264_vaapi -d /dev/dri/renderD128 -x nv12)
            args_ref+=(-p "qp=${quality}")
            log_msg "Using VAAPI Hardware Encoding (h264_vaapi)"
            ;;
        hevc_vaapi)
            args_ref+=(-c hevc_vaapi -d /dev/dri/renderD128 -x nv12)
            args_ref+=(-p "qp=${quality}")
            log_msg "Using VAAPI Hardware Encoding (hevc_vaapi)"
            ;;
        libx264|h264)
            args_ref+=(-c libx264 -x yuv420p -p "crf=${quality}" -p "preset=veryfast")
            log_msg "Using Software Encoding (libx264)"
            ;;
        libvpx-vp9|vp9)
            args_ref+=(-c libvpx-vp9 -x yuv420p -p "crf=${quality}" -p "b:v=0" -p "deadline=realtime")
            log_msg "Using Software Encoding (libvpx-vp9)"
            ;;
        *)
            args_ref+=(-c "$chosen_codec" -p "crf=${quality}")
            ;;
    esac
}
