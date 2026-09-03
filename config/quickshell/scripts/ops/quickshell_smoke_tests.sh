#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
qs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/scripts"
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
repo_user="${USER:-$(id -un)}"
source_root="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v shellcheck >/dev/null 2>&1 || { echo "missing shellcheck"; exit 1; }
  echo "ok"
  exit 0
fi

run_self_test() {
  local path="$1"
  local name
  name="$(basename "$path")"
  if [[ ! -f "$path" ]]; then
    echo "  missing: $name"
    return 1
  fi
  if [[ "$path" == *.py ]]; then
    if python3 -m py_compile "$path" >/dev/null 2>&1; then
      echo "  ok: $name"
      return 0
    fi
    echo "  fail: $name"
    return 1
  fi
  local out
  out="$(bash "$path" --self-test 2>&1 || true)"
  if [[ "$out" != *"ok"* ]]; then
    echo "  fail: $name"
    echo "  output: $out"
    return 1
  fi
  echo "  ok: $name"
}

run_self_tests_in_tree() {
  local dir="$1"
  local label="$2"
  local fail=0
  mapfile -t scripts < <(find "$dir" -type f \( -name '*.sh' -o -name '*.py' \) | sort)
  if (( ${#scripts[@]} == 0 )); then
    echo "  no scripts in $label"
    return 1
  fi
  for script in "${scripts[@]}"; do
    if ! run_self_test "$script"; then
      fail=1
    fi
  done
  return "$fail"
}

echo "[smoke] running quickshell script self-tests"
run_self_tests_in_tree "$qs_dir" "quickshell scripts"

echo "[smoke] running hypr script self-tests"
run_self_tests_in_tree "$hypr_dir" "hypr scripts"

echo "[smoke] shellcheck lint"
mapfile -t shell_files < <(find "$qs_dir" "$hypr_dir" -type f -name '*.sh' | sort)
if (( ${#shell_files[@]} == 0 )); then
  echo "  no shell scripts found to lint"
  exit 1
fi
shellcheck -e SC1091 "${shell_files[@]}" >/dev/null

echo "[smoke] python syntax"
mapfile -t python_files < <(find "$qs_dir" "$hypr_dir" -type f -name '*.py' | sort)
for path in "${python_files[@]}"; do
  python3 -m py_compile "$path"
done

echo "[smoke] qmldir integrity"
qmldir_path="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/widgets/qmldir"
if [[ ! -f "$qmldir_path" ]]; then
  echo "  missing qmldir: $qmldir_path"
  exit 1
fi
# shellcheck disable=SC2094
while read -r kind type ver rel _; do
  [[ -z "${kind:-}" ]] && continue
  [[ "$kind" == "module" || "$kind" == "import" ]] && continue
  file_rel="$rel"
  if [[ "$kind" != "singleton" ]]; then
    file_rel="$ver"
  fi
  if [[ ! -f "$(dirname "$qmldir_path")/$file_rel" ]]; then
    echo "  missing qml for $type: $file_rel"
    exit 1
  fi
done < "$qmldir_path"

echo "[smoke] hardcoded path audit"
if [[ ! -d "$source_root" ]]; then
  source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
user_home_marker="/home/${repo_user}"
hardcoded="$(rg -n "$user_home_marker" "$source_root" \
  -g '!quickshell/scripts/quickshell_audit_report.sh' \
  -g '!**/*.md' || true)"
if [[ -n "$hardcoded" ]]; then
  echo "$hardcoded"
  echo "hardcoded user-home paths found"
  exit 1
fi

echo "[smoke] quickshell runtime health"
echo "[smoke] cold-start restart"
systemctl --user restart quickshell
systemctl --user is-active --quiet quickshell
current_pid="$(systemctl --user show quickshell -p MainPID --value 2>/dev/null || true)"
if [[ -z "$current_pid" || "$current_pid" == "0" ]]; then
  echo "unable to determine quickshell pid after restart"
  exit 1
fi

pid_logs=""
loaded=0
for _ in $(seq 1 12); do
  pid_logs="$(journalctl --user "_PID=${current_pid}" --no-pager -n 200)"
  if printf '%s\n' "$pid_logs" | grep -q "Configuration Loaded"; then
    loaded=1
    break
  fi
  sleep 1
done
if [[ "$loaded" -ne 1 ]]; then
  echo "missing 'Configuration Loaded' in recent quickshell logs"
  exit 1
fi
if printf '%s\n' "$pid_logs" | grep -E 'ERROR|TypeError|ReferenceError|Failed to load configuration' >/dev/null; then
  echo "critical runtime errors detected after cold-start restart"
  printf '%s\n' "$pid_logs" | grep -E 'ERROR|TypeError|ReferenceError|Failed to load configuration'
  exit 1
fi

echo "[smoke] success"
