#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
script_dir="${config_dir}/hypr/scripts"
state_file="${state_dir}/context-profile"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v powerprofilesctl >/dev/null 2>&1 || exit 1
    command -v quickshell >/dev/null 2>&1 || exit 1
    command -v systemctl >/dev/null 2>&1 || exit 1
    [[ -x "${script_dir}/scene_preset.sh" ]] || exit 1
    echo "ok"
    exit 0
fi
profiles=(work study gaming streaming presentation)
arg="${1:-cycle}"

if [[ "$arg" == "cycle" ]]; then
    current="work"
    [[ -f "$state_file" ]] && current="$(cat "$state_file" 2>/dev/null || echo work)"
    idx=0
    for i in "${!profiles[@]}"; do
        if [[ "${profiles[$i]}" == "$current" ]]; then
            idx="$i"
            break
        fi
    done
    arg="${profiles[$(( (idx + 1) % ${#profiles[@]} ))]}"
fi

profile="$arg"
valid=0
for p in "${profiles[@]}"; do
    [[ "$p" == "$profile" ]] && valid=1
done
[[ "$valid" -eq 1 ]] || { notify-send -a "Hyprland" "Context profile" "Perfil inválido: $profile"; exit 1; }

case "$profile" in
    work)
        powerprofilesctl set balanced >/dev/null 2>&1 || true
        quickshell ipc call ipcHandler setDndOff >/dev/null 2>&1 || true
        systemctl --user start hypridle.service >/dev/null 2>&1 || true
        ;;
    study)
        powerprofilesctl set power-saver >/dev/null 2>&1 || true
        systemctl --user start hypridle.service >/dev/null 2>&1 || true
        ;;
    gaming)
        powerprofilesctl set performance >/dev/null 2>&1 || true
        systemctl --user stop hypridle.service >/dev/null 2>&1 || true
        ;;
    streaming)
        powerprofilesctl set performance >/dev/null 2>&1 || true
        systemctl --user stop hypridle.service >/dev/null 2>&1 || true
        ;;
    presentation)
        powerprofilesctl set balanced >/dev/null 2>&1 || true
        systemctl --user stop hypridle.service >/dev/null 2>&1 || true
        ;;
esac

mkdir -p "$state_dir"
"${script_dir}/scene_preset.sh" "$profile" --no-launch >/dev/null 2>&1 || true
printf '%s\n' "$profile" > "$state_file"
notify-send -a "Hyprland" "Context profile" "Perfil ativo: ${profile}"
