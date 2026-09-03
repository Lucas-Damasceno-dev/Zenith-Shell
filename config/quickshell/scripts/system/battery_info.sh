#!/usr/bin/env bash
set -euo pipefail

# Ensure standard paths are available, but don't override the environment's PATH
# which is crucial in Nix environments.
if [[ -d "/run/current-system/sw/bin" ]]; then
  export PATH="/run/current-system/sw/bin:${PATH}"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

if [[ "${1:-}" == "--self-test" ]]; then
  command -v upower >/dev/null 2>&1 || { echo "missing upower"; exit 1; }
  command -v systemd-inhibit >/dev/null 2>&1 || { echo "missing systemd-inhibit"; exit 1; }
  echo "ok"
  exit 0
fi

command_name="${1:-percent}"
pid_file="${2:-$(qs_runtime_file "quickshell-caffeine.pid")}" 

UPOWER_BIN="${BATTERY_UPOWER_BIN:-upower}"

POWER_SUPPLY_DIR="${BATTERY_POWER_SUPPLY_DIR:-/sys/class/power_supply}"

# Paths for battery charge threshold control
LENOVO_PATH="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

battery_device() {
  "$UPOWER_BIN" -e 2>/dev/null | grep -m1 -E 'battery|BAT' || true
}

read_percent() {
  local dev
  dev="$(battery_device)"
  [[ -n "$dev" ]] || return 0
  # Ensure we only use the first line if multiple were returned (though grep -m1 should prevent this)
  dev="$(echo "$dev" | head -n1)"
  
  "$UPOWER_BIN" -i "$dev" 2>/dev/null | awk '/percentage:/ {
    # Extract the percentage value regardless of which field it is in
    for (i=1; i<=NF; i++) {
      if ($i ~ /[0-9]+%/) {
        gsub("%", "", $i);
        print $i;
        exit;
      }
    }
  }'
}

battery_sysfs_device() {
  local dev type

  for dev in "$POWER_SUPPLY_DIR"/*; do
    [[ -d "$dev" ]] || continue
    [[ -r "$dev/type" ]] || continue

    type="$(<"$dev/type")"
    type="${type//$'\r'/}"
    if [[ "$type" == "Battery" ]]; then
      printf '%s\n' "$dev"
      return 0
    fi
  done

  return 1
}

read_sysfs_value() {
  local path="$1"
  local value

  [[ -r "$path" ]] || return 1
  value="$(<"$path")"
  value="${value//$'\r'/}"
  printf '%s\n' "$value"
}

read_sysfs_health() {
  local dev="$1"
  local full=""
  local design=""
  local health=""

  full="$(read_sysfs_value "$dev/energy_full" 2>/dev/null || true)"
  design="$(read_sysfs_value "$dev/energy_full_design" 2>/dev/null || true)"

  if [[ ! "$full" =~ ^[0-9.]+$ || ! "$design" =~ ^[0-9.]+$ ]]; then
    full="$(read_sysfs_value "$dev/charge_full" 2>/dev/null || true)"
    design="$(read_sysfs_value "$dev/charge_full_design" 2>/dev/null || true)"
  fi

  if [[ "$full" =~ ^[0-9.]+$ && "$design" =~ ^[0-9.]+$ ]]; then
    health="$(awk -v full="$full" -v design="$design" 'BEGIN { if (design > 0) printf "%.1f%%", (full / design) * 100; else print "" }')"
  fi

  printf '%s\n' "$health"
}

read_details() {
  local sys_dev
  sys_dev="$(battery_sysfs_device || true)"
  
  local upower_dev
  upower_dev="$(battery_device)"

  local model="" cycles="" health=""

  # Try to get model, cycles and health from sysfs first (fastest, in-kernel)
  if [[ -n "$sys_dev" ]]; then
    model="$(read_sysfs_value "$sys_dev/model_name" 2>/dev/null || true)"
    [[ -n "$model" ]] || model="$(read_sysfs_value "$sys_dev/manufacturer" 2>/dev/null || true)"
    [[ -n "$model" ]] || model="$(read_sysfs_value "$sys_dev/serial_number" 2>/dev/null || true)"
    
    cycles="$(read_sysfs_value "$sys_dev/cycle_count" 2>/dev/null || true)"
    health="$(read_sysfs_health "$sys_dev")"
  fi

  # Fallback to upower ONLY if essential fields are missing
  if [[ -z "$model" || "$model" == "N/A" || -z "$cycles" || "$cycles" == "-1" || -z "$health" || "$health" == "N/A" ]]; then
    if [[ -n "$upower_dev" ]]; then
      local upower_info
      upower_info="$("$UPOWER_BIN" -i "$upower_dev" 2>/dev/null || true)"
      
      if [[ -n "$upower_info" ]]; then
        [[ -z "$model" || "$model" == "N/A" ]] && model="$(echo "$upower_info" | awk -F: '/model:/ {print $2; exit}' | xargs)"
        [[ -z "$model" || "$model" == "N/A" ]] && model="$(echo "$upower_info" | awk -F: '/vendor:/ {print $2; exit}' | xargs)"
        
        [[ -z "$cycles" || "$cycles" == "-1" ]] && cycles="$(echo "$upower_info" | awk -F: '/charge-cycles:/ {print $2; exit}' | xargs)"
        
        if [[ -z "$health" || "$health" == "N/A" ]]; then
          health="$(echo "$upower_info" | awk -F: '/capacity:/ {print $2; exit}' | xargs)"
        fi
      fi
    fi
  fi

  [[ -n "$model" ]] || model="N/A"
  [[ "$cycles" =~ ^[0-9]+$ ]] || cycles="-1"
  [[ -n "$health" ]] || health="N/A"

  echo "cycles=${cycles:--1}"
  echo "wear=${health:-N/A}"
  echo "health=${health:-N/A}"
  echo "model=${model}"
}

find_threshold_file() {
  if [[ -f "$LENOVO_PATH" ]]; then
    echo "$LENOVO_PATH:lenovo"
    return 0
  fi
  local f
  for f in "$POWER_SUPPLY_DIR"/BAT*/charge_control_end_threshold "$POWER_SUPPLY_DIR"/BAT*/charge_stop_threshold "$POWER_SUPPLY_DIR"/battery*/charge_control_end_threshold; do
    if [[ -f "$f" ]]; then
      echo "$f:standard"
      return 0
    fi
  done
  return 1
}

limit_status() {
  local entry path type val
  entry="$(find_threshold_file 2>/dev/null || true)"
  [[ -n "$entry" ]] || { echo "-1"; return 0; }

  path="${entry%%:*}"
  type="${entry##*:}"

  if [[ "$type" == "lenovo" ]]; then
    read -r val < "$path" 2>/dev/null || val="-1"
    echo "${val:- -1}"
  else
    read -r val < "$path" 2>/dev/null || val="100"
    [[ "$val" =~ ^[0-9]+$ && "$val" -lt 100 ]] && echo "1" || echo "0"
  fi
}

limit_enable() {
  local entry path type
  entry="$(find_threshold_file 2>/dev/null || true)"
  [[ -n "$entry" ]] || return 0

  path="${entry%%:*}"
  type="${entry##*:}"

  if [[ "$type" == "lenovo" ]]; then
    echo "1" > "$path" 2>/dev/null || true
  else
    echo "80" > "$path" 2>/dev/null || true
  fi
}

limit_disable() {
  local entry path type
  entry="$(find_threshold_file 2>/dev/null || true)"
  [[ -n "$entry" ]] || return 0

  path="${entry%%:*}"
  type="${entry##*:}"

  if [[ "$type" == "lenovo" ]]; then
    echo "0" > "$path" 2>/dev/null || true
  else
    echo "100" > "$path" 2>/dev/null || true
  fi
}

caffeine_status() {
  local pid=""
  if [[ -f "$pid_file" ]]; then
    read -r pid < "$pid_file" || true
  fi
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "1"
  else
    echo "0"
  fi
}

caffeine_start() {
  caffeine_stop
  nohup systemd-inhibit --what=idle --who=quickshell --why="Caffeine" sleep infinity >/dev/null 2>&1 &
  local pid=$!
  printf '%s\n' "$pid" > "$pid_file"
}

caffeine_stop() {
  local pid=""
  if [[ -f "$pid_file" ]]; then
    read -r pid < "$pid_file" || true
  fi
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

read_uptime() {
  local up_sec
  if [[ -r /proc/uptime ]]; then
    read -r up_sec _ < /proc/uptime
    up_sec="${up_sec%%.*}"
    local days=$(( up_sec / 86400 ))
    local hours=$(( (up_sec % 86400) / 3600 ))
    local mins=$(( (up_sec % 3600) / 60 ))
    if (( days > 0 )); then
      printf '%dd %dh %dm\n' "$days" "$hours" "$mins"
    elif (( hours > 0 )); then
      printf '%dh %dm\n' "$hours" "$mins"
    else
      printf '%dm\n' "$mins"
    fi
  else
    uptime -p 2>/dev/null || echo "N/A"
  fi
}

case "$command_name" in
  percent)
    read_percent
    ;;
  details)
    read_details
    ;;
  uptime)
    read_uptime
    ;;
  caffeine-status)
    caffeine_status
    ;;
  caffeine-start)
    caffeine_start
    ;;
  caffeine-stop)
    caffeine_stop
    ;;
  limit-status)
    limit_status
    ;;
  limit-enable)
    limit_enable
    ;;
  limit-disable)
    limit_disable
    ;;
  *)
    echo "unknown command: $command_name" >&2
    exit 1
    ;;
esac
