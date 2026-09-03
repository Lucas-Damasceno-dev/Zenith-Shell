#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
script_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v loginctl >/dev/null 2>&1 || exit 1
  [[ -x "${script_dir}/hypridle_can_run_action.sh" ]] || exit 1
  echo "ok"
  exit 0
fi

"${script_dir}/hypridle_can_run_action.sh" || exit 0
loginctl lock-session >/dev/null 2>&1 || true
