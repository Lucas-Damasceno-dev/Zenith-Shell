#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
script_dir="${config_dir}/hypr/scripts"
backend="${HYPR_MONITOR_BACKEND:-script}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
last_refresh_file="${state_dir}/quickshell-hotplug.last"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v socat >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    command -v systemctl >/dev/null 2>&1 || exit 1
    [[ -x "${script_dir}/monitor_profile.sh" ]] || exit 1
    echo "ok"
    exit 0
fi

if [[ "$backend" == "kanshi" ]]; then
    kanshi_config="${XDG_CONFIG_HOME:-$HOME/.config}/kanshi/config"
    if command -v kanshi >/dev/null 2>&1 && [[ -f "$kanshi_config" ]]; then
        exec kanshi -c "$kanshi_config"
    fi
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

trigger_profile() {
    mkdir -p "$state_dir"
    local now last
    now="$(date +%s)"
    last=0
    if [[ -f "$last_refresh_file" ]]; then
        read -r last < "$last_refresh_file" || last=0
    fi
    if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < 2 )); then
        return 0
    fi
    printf '%s\n' "$now" > "$last_refresh_file"

    "${script_dir}/monitor_profile.sh" --auto >/dev/null 2>&1 || true
    local focused
    focused="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null | head -n1)" || true
    [[ -n "$focused" ]] && hyprctl dispatch focusmonitor "$focused" >/dev/null 2>&1 || true
    quickshell -p "${config_dir}/quickshell" ipc --any-display call ipcHandler onMonitorsChanged >/dev/null 2>&1 || quickshell ipc --any-display call ipcHandler onMonitorsChanged >/dev/null 2>&1 || true
}

while true; do
    socket_path="$(resolve_socket || true)"
    if [[ -z "$socket_path" ]]; then
        sleep 2
        continue
    fi

    socat -u "UNIX-CONNECT:${socket_path}" - 2>/dev/null | while read -r line; do
        case "$line" in
            monitoradded*|monitorremoved*|monitorrenamed*)
                trigger_profile
                ;;
        esac
    done || true
    sleep 1
done
