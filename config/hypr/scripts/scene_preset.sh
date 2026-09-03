#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
script_dir="${config_dir}/hypr/scripts"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v notify-send >/dev/null 2>&1 || exit 1
    [[ -x "${script_dir}/monitor_profile.sh" ]] || exit 1
    echo "ok"
    exit 0
fi

preset="work"
launch_apps=1

for arg in "$@"; do
    case "$arg" in
        --no-launch)
            launch_apps=0
            ;;
        work|study|gaming|streaming|presentation)
            preset="$arg"
            ;;
    esac
done

open_if_missing() {
    local proc="$1"
    shift
    if ! pgrep -x "$proc" >/dev/null 2>&1; then
        "$@" >/dev/null 2>&1 &
    fi
}

case "$preset" in
    work)
        hyprctl keyword general:layout master >/dev/null 2>&1 || true
        "${script_dir}/monitor_profile.sh" --auto >/dev/null 2>&1 || true
        hyprctl dispatch workspace 1 >/dev/null 2>&1 || true
        if [[ "$launch_apps" -eq 1 ]]; then
            open_if_missing brave brave
        fi
        ;;
    study)
        hyprctl keyword general:layout dwindle >/dev/null 2>&1 || true
        hyprctl dispatch workspace 3 >/dev/null 2>&1 || true
        if [[ "$launch_apps" -eq 1 ]]; then
            open_if_missing kitty kitty
        fi
        ;;
    gaming)
        hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true
        hyprctl keyword animations:enabled 0 >/dev/null 2>&1 || true
        hyprctl dispatch workspace 9 >/dev/null 2>&1 || true
        if [[ "$launch_apps" -eq 1 ]]; then
            open_if_missing steam steam
        fi
        ;;
    streaming)
        hyprctl keyword general:layout master >/dev/null 2>&1 || true
        hyprctl dispatch workspace 8 >/dev/null 2>&1 || true
        if [[ "$launch_apps" -eq 1 ]]; then
            open_if_missing obs obs
        fi
        ;;
    presentation)
        hyprctl dispatch workspace 1 >/dev/null 2>&1 || true
        hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true
        ;;
    *)
        notify-send -a "Hyprland" "Scene preset" "Preset inválido: $preset"
        exit 1
        ;;
esac

mkdir -p "$state_dir"
printf '%s\n' "$preset" > "${state_dir}/scene-preset"
notify-send -a "Hyprland" "Scene preset" "Aplicado: ${preset}"
