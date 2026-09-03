#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

log_file="$(qs_runtime_file "quickshell-dashboard-services.log")"
touch "$log_file"

log() {
    printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$log_file"
}

status() {
    local services=(
        "quickshell.service|Quickshell"
        "pipewire.service|PipeWire"
        "wireplumber.service|WirePlumber"
        "xdg-desktop-portal.service|Portal"
        "xdg-desktop-portal-hyprland.service|Portal Hyprland"
        "hypridle.service|Hypridle"
    )
    local item svc label state
    for item in "${services[@]}"; do
        svc="${item%%|*}"
        label="${item##*|}"
        state="$(systemctl --user is-active "$svc" 2>/dev/null || true)"
        [[ -n "$state" ]] || state="unknown"
        printf '%s\t%s\t%s\n' "$svc" "$label" "$state"
    done
}

restart_service() {
    local svc="$1"
    if [[ -z "$svc" ]]; then
        echo "ERROR: serviço inválido" >&2
        exit 1
    fi
    systemctl --user restart "$svc"
    log "restarted $svc"
    notify-send -a "Dashboard" "Serviço reiniciado" "$svc"
}

quick_fix() {
    local target="$1"
    case "$target" in
        network)
            nmcli networking off >/dev/null 2>&1 || true
            sleep 1
            nmcli networking on >/dev/null 2>&1 || true
            notify-send -a "Dashboard" "Quick fix" "Rede reinicializada"
            ;;
        audio)
            systemctl --user restart pipewire.service wireplumber.service
            notify-send -a "Dashboard" "Quick fix" "PipeWire reiniciado"
            ;;
        portal)
            systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service
            notify-send -a "Dashboard" "Quick fix" "Portal reiniciado"
            ;;
        quickshell)
            systemctl --user restart quickshell.service
            ;;
        hyprland)
            hyprctl reload >/dev/null 2>&1 || true
            notify-send -a "Dashboard" "Quick fix" "Hyprland recarregado"
            ;;
        *)
            echo "ERROR: quick-fix inválido ($target)" >&2
            exit 1
            ;;
    esac
}

cmd="${1:-status}"
case "$cmd" in
    status)
        status
        ;;
    restart)
        restart_service "${2:-}"
        ;;
    quick-fix)
        quick_fix "${2:-}"
        ;;
    *)
        echo "ERROR: comando inválido ($cmd)" >&2
        exit 1
        ;;
esac
