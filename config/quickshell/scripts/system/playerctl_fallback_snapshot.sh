#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v playerctl >/dev/null 2>&1 || { echo "missing playerctl"; exit 1; }
  echo "ok"
  exit 0
fi

playerctl metadata --all-players --format '{{status}}|{{playerName}}|{{xesam:title}}|{{xesam:artist}}|{{mpris:artUrl}}|{{xesam:url}}' 2>/dev/null || true
