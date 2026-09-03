#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
state_file="${state_dir}/thermal-profile.state"
ac_profile="${THERMAL_AC_PROFILE:-balanced}"
battery_profile="${THERMAL_BATTERY_PROFILE:-power-saver}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v upower >/dev/null 2>&1 || exit 1
    command -v powerprofilesctl >/dev/null 2>&1 || exit 1
    command -v hyprctl >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

mkdir -p "$state_dir"

is_on_ac() {
    local has_battery=0 ps online status
    for ps in /sys/class/power_supply/BAT*; do
        [[ -d "$ps" ]] && has_battery=1 && break
    done
    # Se não possui baterias (Desktop/VM), está sempre em AC
    [[ "$has_battery" -eq 0 ]] && return 0

    for ps in /sys/class/power_supply/*; do
        [[ -d "$ps" ]] || continue
        if [[ -r "$ps/online" ]]; then
            read -r online < "$ps/online" || true
            if [[ "$online" == "1" ]]; then
                return 0
            fi
        fi
        if [[ -r "$ps/status" ]]; then
            read -r status < "$ps/status" || true
            if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

apply_mode() {
    local mode="$1" current_state=""
    if [[ -f "$state_file" ]]; then
        read -r current_state < "$state_file" || true
        [[ "$current_state" == "$mode" ]] && return 0
    fi

    if [[ "$mode" == "ac" ]]; then
        powerprofilesctl set "$ac_profile" >/dev/null 2>&1 || true
        hyprctl keyword decoration:blur:enabled 1 >/dev/null 2>&1 || true
    else
        powerprofilesctl set "$battery_profile" >/dev/null 2>&1 || true
        hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true
    fi

    printf '%s\n' "$mode" > "$state_file"
}

refresh_from_power_source() {
    if is_on_ac; then
        apply_mode "ac"
    else
        apply_mode "battery"
    fi
}

refresh_from_power_source

upower --monitor-detail 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"online:"*|*"state:"*)
            refresh_from_power_source
            ;;
    esac
done
