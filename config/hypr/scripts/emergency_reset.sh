#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

hyprctl reload >/dev/null 2>&1 || true

ZENITH_REPO="${HOME}/Documents/03_Desenvolvimento/code/projects/personal/portfolio/desktop/Zenith-Shell"
ZENITH_BIN="${ZENITH_REPO}/target/release/zenith"
ZENITH_SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/zenith.sock"

if [[ -S "$ZENITH_SOCKET" ]] || pgrep -x zenith >/dev/null 2>&1; then
    if [[ -x "$ZENITH_BIN" ]]; then
        "$ZENITH_BIN" reload >/dev/null 2>&1 || true
    elif command -v zenith >/dev/null 2>&1; then
        zenith reload >/dev/null 2>&1 || true
    fi
    systemctl --user restart zenith >/dev/null 2>&1 || true
    notify-send -a "Zenith" "Emergency reset" "Compositor e Zenith-Shell recarregados"
else
    systemctl --user restart quickshell >/dev/null 2>&1 || true
    notify-send -a "Hyprland" "Emergency reset" "Compositor recarregado e Quickshell reiniciado"
fi

