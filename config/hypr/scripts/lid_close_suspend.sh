#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pid_file="${runtime_dir}/hypr-lid-suspend.pid"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v loginctl >/dev/null 2>&1 || exit 1
    command -v systemctl >/dev/null 2>&1 || exit 1
    [[ -x "${script_dir}/hypridle_can_run_action.sh" ]] || exit 1
    echo "ok"
    exit 0
fi

if [[ "${1:-}" == "--cancel" ]]; then
    if [[ -f "$pid_file" ]]; then
        old_pid="$(cat "$pid_file" 2>/dev/null || true)"
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    fi
    exit 0
fi

lid_is_closed() {
    local lid_file
    for lid_file in /proc/acpi/button/lid/*/state; do
        [[ -f "$lid_file" ]] || continue
        if grep -qi 'closed' "$lid_file"; then
            return 0
        fi
    done
    return 1
}

loginctl lock-session >/dev/null 2>&1 || true

old_pid="$(cat "$pid_file" 2>/dev/null || true)"
if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null || true
fi

(
    sleep 30
    "${script_dir}/hypridle_can_run_action.sh" || exit 0
    lid_is_closed || exit 0
    systemctl suspend >/dev/null 2>&1 || true
) &
printf '%s\n' "$!" > "$pid_file"
