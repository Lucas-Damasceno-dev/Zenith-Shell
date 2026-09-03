#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl &>/dev/null || { echo "FAIL: hyprctl not found"; exit 1; }
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_file="${runtime_dir}/quickshell_presentation.state"
pid_file="${runtime_dir}/quickshell_presentation.pid"
mode="${1:-toggle}"

if [[ "$mode" == "toggle" ]]; then
    if [[ -f "$state_file" ]]; then mode="off"; else mode="on"; fi
fi

if [[ "$mode" == "on" ]]; then
    touch "$state_file"
    
    # 1. Disable notifications
    if command -v quickshell >/dev/null 2>&1; then quickshell ipc call ipcHandler setDndOn >/dev/null 2>&1 || true; fi
    if command -v dunstctl >/dev/null 2>&1; then dunstctl set-paused true || true; fi
    if command -v makoctl >/dev/null 2>&1; then makoctl mode -a do-not-disturb || true; fi

    # 2. Inhibit Idle
    # We use systemd-inhibit in background and store PID
    systemd-inhibit --what=idle --who=quickshell --why="Presentation Mode" --mode=block sleep infinity &
    echo $! > "$pid_file"

    # 3. Hyprland Specifics (Optional)
    # hyprctl dispatch workspace 1 # Go to clean workspace?
    
    notify-send -u critical -t 3000 "Presentation Mode" "ENABLED: Notifications muted, Idle blocked." || true

elif [[ "$mode" == "off" ]]; then
    rm -f "$state_file"
    
    # 1. Enable notifications
    if command -v quickshell >/dev/null 2>&1; then quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true; fi
    if command -v dunstctl >/dev/null 2>&1; then dunstctl set-paused false || true; fi
    if command -v makoctl >/dev/null 2>&1; then makoctl mode -r do-not-disturb || true; fi

    # 2. Kill Inhibitor
    if [[ -f "$pid_file" ]]; then
        kill "$(cat "$pid_file")" 2>/dev/null || true
        rm -f "$pid_file"
    fi

    notify-send -u normal -t 3000 "Presentation Mode" "DISABLED: Normal operation restored."
fi
