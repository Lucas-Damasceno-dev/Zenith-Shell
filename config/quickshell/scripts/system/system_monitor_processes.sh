#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v ps >/dev/null 2>&1 || { echo "missing ps"; exit 1; }
  echo "ok"
  exit 0
fi

sort_mode="${1:-cpu}"
filter_text="${2:-}"
sort_arg='-%cpu'
[[ "$sort_mode" == "mem" ]] && sort_arg='-%mem'

ps -eo pid=,comm=,%cpu=,%mem= --sort="$sort_arg" | awk -v filter="${filter_text,,}" '
  BEGIN { count=0 }
  {
    pid=$1; comm=$2; cpu=$3; mem=$4;
    lower=tolower(comm);
    if (filter != "" && index(lower, filter) == 0) next;
    printf "%s|%s|%s|%s\n", pid, comm, cpu, mem;
    count++;
    if (count >= 20) exit;
  }
'
