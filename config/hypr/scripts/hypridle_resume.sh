#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v brightnessctl >/dev/null 2>&1 || exit 1
  echo "ok"
  exit 0
fi

brightnessctl -r >/dev/null 2>&1 || true
