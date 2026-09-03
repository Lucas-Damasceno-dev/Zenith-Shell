#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v bash >/dev/null 2>&1 || exit 1
  echo "ok"
  exit 0
fi

mode="${1:-direct}"
command_text="${2:-}"
confirm_flag="${3:-}"

[[ -n "$command_text" ]] || exit 0

normalize_for_match() {
  local text="${1,,}"
  text="${text//\`/ }"
  text="${text//\"/ }"
  text="${text//\'/ }"
  text="$(printf '%s' "$text" | tr -s '[:space:]' ' ')"
  printf '%s\n' "$text"
}

is_dangerous() {
  local raw="${1,,}"
  local text
  text="$(normalize_for_match "$1")"
  [[ "$raw" =~ (^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$) ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])mkfs([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])mkfs([[:space:]]|$) ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])dd[[:space:]]+if= ]] && return 0
  [[ "$text" =~ (^|[[:space:]])dd[[:space:]]+if= ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])(shutdown|reboot|poweroff|halt)([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])(shutdown|reboot|poweroff|halt)([[:space:]]|$) ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])systemctl[[:space:]]+(poweroff|reboot)([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])systemctl[[:space:]]+(poweroff|reboot)([[:space:]]|$) ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])kill[[:space:]]+-9[[:space:]]+1([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])kill[[:space:]]+-9[[:space:]]+1([[:space:]]|$) ]] && return 0
  [[ "$raw" =~ [[:space:]]\>[[:space:]]*/dev/sd[a-z] ]] && return 0
  [[ "$text" =~ [[:space:]]\>[[:space:]]*/dev/sd[a-z] ]] && return 0
  [[ "$raw" =~ :\(\)\ \{:\|:\&\ \}\;: ]] && return 0
  [[ "$raw" == *\$\(* ]] && return 0
  [[ "$raw" == *'`'* ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])eval[[:space:]] ]] && return 0
  [[ "$raw" =~ (^|[[:space:]])(bash|sh|zsh|fish)[[:space:]]+-c([[:space:]]|$) ]] && return 0
  [[ "$text" =~ (^|[[:space:]])(bash|sh|zsh|fish)[[:space:]]+-c([[:space:]]|$) ]] && return 0
  return 1
}

quote_single() {
  printf "%s" "${1:-}" | sed "s/'/'\"'\"'/g"
}

dangerous="0"
if is_dangerous "$command_text"; then
  dangerous="1"
  if [[ "$confirm_flag" != "--confirm-dangerous" ]]; then
    echo "dangerous command requires confirmation"
    exit 10
  fi
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
mkdir -p "$state_dir"
audit_file="${state_dir}/launcher-command-audit.log"
printf '%s\tmode=%s\tdangerous=%s\tcmd=%s\tpath=%s\n' \
  "$(date +%Y-%m-%dT%H:%M:%S)" "$mode" "$dangerous" "$command_text" "$PATH" >> "$audit_file"

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "Error: hyprctl not found in PATH" >> "$audit_file"
  exit 127
fi

case "$mode" in
  direct)
    # Launch via Hyprland exec for proper Wayland process scope (no bash subshell)
    # We use setsid and redirect to ensure the app is fully detached
    exec hyprctl dispatch exec "$command_text" >/dev/null 2>&1
    ;;
  root)
    escaped_cmd="$(quote_single "$command_text")"
    escaped_path="$(quote_single "/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}")"
    escaped_display="$(quote_single "${DISPLAY:-}")"
    escaped_wayland="$(quote_single "${WAYLAND_DISPLAY:-}")"
    escaped_runtime="$(quote_single "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}")"
    escaped_dbus="$(quote_single "${DBUS_SESSION_BUS_ADDRESS:-}")"
    escaped_xauth="$(quote_single "${XAUTHORITY:-}")"
    exec hyprctl dispatch exec "pkexec env PATH='$escaped_path' DISPLAY='$escaped_display' WAYLAND_DISPLAY='$escaped_wayland' XDG_RUNTIME_DIR='$escaped_runtime' DBUS_SESSION_BUS_ADDRESS='$escaped_dbus' XAUTHORITY='$escaped_xauth' /run/current-system/sw/bin/sh -lc '$escaped_cmd'" >/dev/null 2>&1
    ;;
  terminal)
    # Launch in terminal via Hyprland exec dispatcher
    escaped_cmd="$(quote_single "$command_text")"
    exec hyprctl dispatch exec "kitty --hold --title 'Launcher Command' -- bash -lc '$escaped_cmd'" >/dev/null 2>&1
    ;;
  terminal-here)
    # Launch terminal in specific directory
    dir="$command_text"
    if [[ ! -d "$dir" ]]; then dir="$(dirname "$dir")"; fi
    escaped_dir="$(quote_single "$dir")"
    exec hyprctl dispatch exec "kitty --working-directory '$escaped_dir'" >/dev/null 2>&1
    ;;
  editor)
    # Launch editor for specific file
    escaped_target="$(quote_single "$command_text")"
    exec hyprctl dispatch exec "kitty --title '$escaped_target' nvim '$escaped_target'" >/dev/null 2>&1
    ;;
  open)
    # Open path via xdg-open/thunar
    target="$command_text"
    escaped_target="$(quote_single "$target")"
    if [[ -d "$target" ]]; then
      if command -v thunar >/dev/null 2>&1; then
        exec hyprctl dispatch exec "thunar '$escaped_target'" >/dev/null 2>&1
      else
        exec hyprctl dispatch exec "xdg-open '$escaped_target'" >/dev/null 2>&1
      fi
    else
      if command -v thunar >/dev/null 2>&1; then
        exec hyprctl dispatch exec "thunar --select '$escaped_target'" >/dev/null 2>&1
      else
        escaped_parent="$(quote_single "$(dirname "$target")")"
        exec hyprctl dispatch exec "xdg-open '$escaped_parent'" >/dev/null 2>&1
      fi
    fi
    ;;
  *)
    echo "invalid mode: $mode" >&2
    exit 1
    ;;
esac
