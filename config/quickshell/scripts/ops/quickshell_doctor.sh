#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

required_bins=(
  quickshell nmcli bluetoothctl playerctl grim slurp wf-recorder
  hyprpicker tesseract curl jq wl-copy notify-send
  wpctl upower brightnessctl powerprofilesctl hyprctl
  pdfinfo shellcheck
)

base_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts"
ops_dir="${base_dir}/ops"
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
fail=0

echo "[doctor] checking binaries"
for bin in "${required_bins[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    echo "  ok  $bin"
  else
    echo "  fail missing: $bin"
    fail=1
  fi
done

echo "[doctor] checking script syntax"
mapfile -t syntax_files < <(find "$base_dir" "$hypr_dir" \( -type f -o -type l \) \( -name '*.sh' -o -name '*.py' \) | sort)
if (( ${#syntax_files[@]} == 0 )); then
  echo "  fail no shell scripts found"
  fail=1
fi
for path in "${syntax_files[@]}"; do
  script="$(basename "$path")"
  if [[ "$path" == *.py ]]; then
    if python3 -m py_compile "$path" >/dev/null 2>&1; then
      echo "  ok  $script"
    else
      echo "  fail syntax: $script"
      fail=1
    fi
  elif bash -n "$path"; then
    echo "  ok  $script"
  else
    echo "  fail syntax: $script"
    fail=1
  fi
done

echo "[doctor] quickshell systemd state"
if systemctl --user is-active --quiet quickshell; then
  echo "  ok  quickshell.service active"
else
  echo "  fail quickshell.service inactive"
  fail=1
fi

echo "[doctor] recent quickshell errors"
current_pid="$(systemctl --user show quickshell -p MainPID --value 2>/dev/null || true)"
journal_args=(--user --no-pager -n 200)
if [[ -n "$current_pid" && "$current_pid" != "0" ]]; then
  journal_args+=("_PID=${current_pid}")
else
  journal_args+=(-u quickshell)
fi
err_lines="$(journalctl "${journal_args[@]}" | grep -E 'ERROR|TypeError|ReferenceError|Failed to load configuration' || true)"
if [[ -n "$err_lines" ]]; then
  echo "$err_lines"
  fail=1
else
  echo "  ok  no critical errors in recent logs"
fi

echo "[doctor] baseline warning drift"
if ! bash "$ops_dir/quickshell_log_baseline.sh" check; then
  fail=1
fi

if (( fail != 0 )); then
  echo "[doctor] failed"
  exit 1
fi

echo "[doctor] healthy"
