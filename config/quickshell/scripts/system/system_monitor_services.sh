#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v systemctl >/dev/null 2>&1 || { echo "missing systemctl"; exit 1; }
  echo "ok"
  exit 0
fi

systemctl --user list-units --type=service --all --no-legend --no-pager \
  | head -n 40 \
  | awk '{
      unit=$1; active=$3; substate=$4;
      desc="";
      for (i=5; i<=NF; i++) {
        desc = desc $i (i < NF ? " " : "");
      }
      printf "%s|%s|%s|%s\n", unit, active, substate, desc;
    }'
