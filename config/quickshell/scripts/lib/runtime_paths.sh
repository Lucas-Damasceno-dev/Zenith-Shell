#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" && "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "ok"
  exit 0
fi

qs_runtime_root() {
  local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  printf '%s/quickshell\n' "$base"
}

qs_state_root() {
  local base="${XDG_STATE_HOME:-$HOME/.local/state}"
  printf '%s/quickshell\n' "$base"
}

qs_cache_root() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}"
  printf '%s/quickshell\n' "$base"
}

qs_ensure_dirs() {
  mkdir -p "$(qs_runtime_root)" "$(qs_state_root)" "$(qs_cache_root)"
}

qs_runtime_file() {
  printf '%s/%s\n' "$(qs_runtime_root)" "$1"
}

qs_state_file() {
  printf '%s/%s\n' "$(qs_state_root)" "$1"
}

qs_cache_file() {
  printf '%s/%s\n' "$(qs_cache_root)" "$1"
}

qs_detect_wayland_display() {
  # If WAYLAND_DISPLAY is already set, verify the socket exists
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [[ -S "$base/$WAYLAND_DISPLAY" ]]; then
      return 0
    fi
    # Socket doesn't exist, unset and try to detect
    unset WAYLAND_DISPLAY
  fi
  
  local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local socket
  
  # Try common Hyprland socket names first
  for name in "wayland-1" "wayland-0" "wayland-2"; do
    if [[ -S "$base/$name" ]]; then
      export WAYLAND_DISPLAY="$name"
      return 0
    fi
  done
  
  # Fallback: find any wayland socket
  socket="$(find "$base" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | sort | head -n1 || true)"
  if [[ -n "$socket" ]]; then
    export WAYLAND_DISPLAY="$socket"
    return 0
  fi
  
  # Last resort: try Hyprland-specific socket detection
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    for name in "wayland-1" "wayland-0"; do
      if [[ -S "$base/$name" ]]; then
        export WAYLAND_DISPLAY="$name"
        return 0
      fi
    done
  fi
  
  return 1
}
