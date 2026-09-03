#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
  command -v hyprctl >/dev/null 2>&1 || { echo "missing hyprctl"; exit 1; }
  echo "ok"
  exit 0
fi

mode="${1:-off}"
state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell_low_power.state"

apply_layer_rule() {
  hyprctl keyword layerrule "$1" >/dev/null 2>&1 || true
}

disable_quickshell_blur() {
  apply_layer_rule 'blur off, match:namespace quickshell-popup'
  apply_layer_rule 'blur off, match:namespace quickshell-dock'
  apply_layer_rule 'blur off, match:namespace quickshell-tooltip'
  apply_layer_rule 'blur off, match:namespace gtk-layer-shell'
}

restore_quickshell_blur() {
  hyprctl reload >/dev/null 2>&1 || true
}

current_mode=""
if [[ -f "$state_file" ]]; then
  current_mode="$(tr -d '\n' < "$state_file" 2>/dev/null || true)"
fi

if [[ "$current_mode" == "$mode" ]]; then
  exit 0
fi

if [[ "$mode" == "on" ]]; then
  # Aggressive battery saving
  hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true
  hyprctl keyword decoration:shadow:enabled 0 >/dev/null 2>&1 || true
  hyprctl keyword animations:enabled 0 >/dev/null 2>&1 || true
  hyprctl keyword decoration:active_opacity 1.0 >/dev/null 2>&1 || true
  hyprctl keyword decoration:inactive_opacity 1.0 >/dev/null 2>&1 || true
  disable_quickshell_blur
  
  # Notify user space
  echo "on" > "$state_file"
else
  # Restore eye candy
  hyprctl keyword decoration:blur:enabled 1 >/dev/null 2>&1 || true
  hyprctl keyword decoration:shadow:enabled 1 >/dev/null 2>&1 || true
  hyprctl keyword animations:enabled 1 >/dev/null 2>&1 || true
  restore_quickshell_blur

  echo "off" > "$state_file"
fi
