#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
mkdir -p "$state_dir"
host_key="$(hostname -s 2>/dev/null || hostname || echo unknown)"
baseline_file="$state_dir/log-baseline-${host_key}.txt"
allowlist_file="$state_dir/log-allowlist-${host_key}.txt"
mode="${1:-capture}"

collect_lines() {
  current_pid="$(systemctl --user show quickshell -p MainPID --value 2>/dev/null || true)"
  journal_args=(--user --no-pager -n 500)
  if [[ -n "$current_pid" && "$current_pid" != "0" ]]; then
    journal_args+=("_PID=${current_pid}")
  else
    journal_args+=(-u quickshell)
  fi
  journalctl "${journal_args[@]}" \
    | grep -E 'WARN|ERROR|TypeError|ReferenceError|Failed to load configuration' \
    | sed -E 's/^.*quickshell\[[0-9]+\]: //' \
    | sed -E 's/[[:space:]]+/ /g' \
    | sort -u
}

apply_allowlist() {
  local file_in="$1"
  local file_out="$2"
  cp "$file_in" "$file_out"

  local builtin_rules=(
    "quickshell\\.io\\.fileview: got operation finished from dropped operation"
    "Could not load icon \"preferences-desktop-theme\""
    "Could not load icon \"application-x-executable\""
    "quickshell\\.dbus\\.properties: Error updating properties of org\\.mpris\\.MediaPlayer2\\."
    "quickshell\\.dbus\\.properties: QDBusError\\(\"org\\.freedesktop\\.DBus\\.Error\\.NoReply\""
    "Failed to register with host portal"
  )
  for rule in "${builtin_rules[@]}"; do
    grep -Ev "$rule" "$file_out" > "${file_out}.tmp" || true
    mv "${file_out}.tmp" "$file_out"
  done

  if [[ -f "$allowlist_file" ]]; then
    while IFS= read -r rule; do
      [[ -z "$rule" || "$rule" =~ ^# ]] && continue
      grep -Ev "$rule" "$file_out" > "${file_out}.tmp" || true
      mv "${file_out}.tmp" "$file_out"
    done < "$allowlist_file"
  fi
}

capture() {
  tmp="$(mktemp)"
  collect_lines > "$tmp" || true
  apply_allowlist "$tmp" "$baseline_file"
  rm -f "$tmp"
  echo "baseline captured at $baseline_file"
  if [[ ! -f "$allowlist_file" ]]; then
    cat > "$allowlist_file" <<'EOF'
# One regex per line to ignore known warnings.
# Example:
# Unable to assign \[undefined\]
EOF
    echo "allowlist created at $allowlist_file"
  fi
}

check() {
  if [[ ! -f "$baseline_file" ]]; then
    echo "baseline not found, run: $0 capture"
    exit 1
  fi
  current="$(mktemp)"
  filtered="$(mktemp)"
  trap 'rm -f "$current" "$filtered"' EXIT
  collect_lines > "$current" || true
  apply_allowlist "$current" "$filtered"

  if [[ ! -s "$filtered" ]]; then
    echo "no warnings/errors detected"
    exit 0
  fi

  if diff -u "$baseline_file" "$filtered" >/dev/null 2>&1; then
    echo "only known baseline warnings"
  else
    echo "new warnings/errors detected"
    diff -u "$baseline_file" "$filtered" || true
    exit 1
  fi
}

case "$mode" in
  capture) capture ;;
  check) check ;;
  *) echo "usage: $0 [capture|check]"; exit 1 ;;
esac
