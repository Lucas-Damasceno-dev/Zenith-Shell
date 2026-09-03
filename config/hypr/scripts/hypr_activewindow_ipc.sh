#!/usr/bin/env bash
set -euo pipefail

emit_file=""
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        --emit-file)
            emit_file="${2:-}"
            shift 2
            ;;
        --self-test)
            command -v socat >/dev/null 2>&1 || exit 1
            command -v jq >/dev/null 2>&1 || exit 1
            echo "ok"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -n "$emit_file" ]]; then
    mkdir -p "$(dirname "$emit_file")"
    : > "$emit_file"
fi

socket_is_live() {
    local sock="$1" sig
    [[ -S "$sock" ]] || return 1
    sig="$(basename "$(dirname "$sock")")"
    HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl instanceinfo >/dev/null 2>&1
}

resolve_socket() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local base_dir="${runtime_dir}/hypr"
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"

    if [[ -n "$sig" ]]; then
        if socket_is_live "${base_dir}/${sig}/.socket2.sock"; then
            printf '%s\n' "${base_dir}/${sig}/.socket2.sock"
            return 0
        fi
        return 1
    fi

    local dir
    while IFS= read -r dir; do
        sig="$(basename "$dir")"
        if socket_is_live "${base_dir}/${sig}/.socket2.sock"; then
            printf '%s\n' "${base_dir}/${sig}/.socket2.sock"
            return 0
        fi
    done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)

    return 1
}

emit_payload() {
    local payload="$1"
    printf '%s\n' "$payload"
    if [[ -n "$emit_file" ]]; then
        mkdir -p "$(dirname "$emit_file")"
        # Truncate if larger than 512KB to prevent unbounded growth
        if [[ -f "$emit_file" && $(stat -c%s "$emit_file" 2>/dev/null || echo 0) -gt 524288 ]]; then
            : > "$emit_file"
        fi
        printf '%s\n' "$payload" >> "$emit_file"
    fi
}

last_key=""
current_class=""
current_title=""
current_address=""

emit_activewindow() {
    local key esc_class esc_title esc_addr ts
    key="${current_address}|${current_class}|${current_title}"
    [[ -n "$current_address" || -n "$current_class" || -n "$current_title" ]] || return
    [[ "$key" == "$last_key" ]] && return
    last_key="$key"

    esc_class="${current_class//\\/\\\\}"
    esc_class="${esc_class//\"/\\\"}"
    esc_title="${current_title//\\/\\\\}"
    esc_title="${esc_title//\"/\\\"}"
    esc_addr="${current_address//\\/\\\\}"
    esc_addr="${esc_addr//\"/\\\"}"
    ts="${EPOCHSECONDS:-$(date +%s)}"

    emit_payload "{\"event\":\"activewindow\",\"class\":\"${esc_class}\",\"title\":\"${esc_title}\",\"address\":\"${esc_addr}\",\"ts\":${ts}}"
}

while true; do
    socket_path="$(resolve_socket || true)"
    if [[ -z "$socket_path" ]]; then
        sleep 1
        continue
    fi

    while IFS= read -r line; do
        case "$line" in
            "activewindow>>"*)
                payload="${line#activewindow>>}"
                current_address=""
                if [[ "$payload" == *","* ]]; then
                    current_class="${payload%%,*}"
                    current_title="${payload#*,}"
                else
                    current_class="$payload"
                    current_title=""
                fi
                emit_activewindow
                ;;
            "activewindowv2>>"*)
                current_address="${line#activewindowv2>>}"
                emit_activewindow
                ;;
        esac
    done < <(socat -u "UNIX-CONNECT:${socket_path}" - 2>/dev/null || true)

    # Se chegamos aqui, o socat fechou ou falhou. 
    # Aguardamos um pouco antes de tentar a próxima iteração do loop externo.
    sleep 1
done
