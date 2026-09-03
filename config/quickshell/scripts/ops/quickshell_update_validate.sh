#!/usr/bin/env bash
set -euo pipefail

user_name="${USER:-$(id -un)}"
script_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts/ops"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v nix >/dev/null 2>&1 || { echo "missing nix"; exit 1; }
  command -v home-manager >/dev/null 2>&1 || { echo "missing home-manager"; exit 1; }
  echo "ok"
  exit 0
fi

detect_repo_root() {
  local root=""
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$root" && -f "$root/flake.nix" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  root="$(git -C /etc/nixos rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$root" && -f "$root/flake.nix" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  if [[ -f "/etc/nixos/flake.nix" ]]; then
    printf '%s\n' "/etc/nixos"
    return 0
  fi
  return 1
}

repo_root="$(detect_repo_root || true)"
if [[ -z "$repo_root" ]]; then
  echo "unable to detect repository root"
  exit 1
fi
home_flake="path:${repo_root}/home/${user_name}#${user_name}"

echo "[update] nix flake check"
cd "$repo_root"
nix flake check

echo "[update] home-manager build"
home-manager build --flake "$home_flake"

echo "[update] quickshell doctor"
  bash "$script_dir/quickshell_doctor.sh"

echo "[update] hyprctl configerrors"
config_errors_output="$(hyprctl configerrors 2>/dev/null || true)"
config_errors_trimmed="$(printf '%s' "$config_errors_output" | tr -d '[:space:]')"
if [[ -n "$config_errors_trimmed" ]] && ! printf '%s' "$config_errors_output" | grep -qiE "no[[:space:]]*errors|none"; then
  echo "hyprctl configerrors reported issues"
  printf '%s\n' "$config_errors_output"
  exit 1
fi

echo "[update] log baseline check"
  bash "$script_dir/quickshell_log_baseline.sh" check

echo "[update] backup/restore safety self-test"
  bash "$script_dir/quickshell_backup_restore.sh" --self-test

echo "[update] smoke tests"
  bash "$script_dir/quickshell_smoke_tests.sh"

echo "[update] done"
