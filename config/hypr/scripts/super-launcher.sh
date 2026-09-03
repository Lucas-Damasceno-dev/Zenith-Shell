#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v quickshell >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_file="${runtime_dir}/hypr-super-last-combo"
now_ms="$(date +%s%3N)"
last_ms="0"
if [[ -f "$state_file" ]]; then
    last_ms="$(cat "$state_file" 2>/dev/null || echo 0)"
fi

# Ignore launcher trigger if a SUPER combo was just used.
if [[ "$last_ms" =~ ^[0-9]+$ ]] && (( now_ms - last_ms <= 500 )); then
    exit 0
fi

# notify-send -a Quickshell "Launcher" "Triggering Super alone"
# Try direct hyprland global first as it's most reliable if registered
# if hyprctl dispatch global quickshell:launcher >/dev/null 2>&1; then
#     exit 0
# fi

QS_CANDIDATES=(
    "$(command -v quickshell 2>/dev/null || true)"
    "${HOME}/.nix-profile/bin/quickshell"
    "/run/current-system/sw/bin/quickshell"
)

# Try candidates directly
for q in "${QS_CANDIDATES[@]}"; do
    if [[ -n "$q" && -x "$q" ]]; then
        exec "$q" ipc --any-display call ipcHandler toggleLauncher
    fi
done

# Final best-effort fallback: try quickshell from PATH (ignore failures)
exec quickshell ipc --any-display call ipcHandler toggleLauncher 2>/dev/null || true
