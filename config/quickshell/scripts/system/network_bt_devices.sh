#!/usr/bin/env bash
set -euo pipefail

user_nix_profile=""
if [[ -n "${HOME:-}" ]]; then
  user_nix_profile="${HOME}/.nix-profile/bin"
fi
path_prefix="${PATH:-}"
if [[ -n "$path_prefix" ]]; then
  path_prefix="$path_prefix:/run/current-system/sw/bin"
else
  path_prefix="/run/current-system/sw/bin"
fi
if [[ -n "$user_nix_profile" ]]; then
  path_prefix="$path_prefix:$user_nix_profile"
fi
export PATH="$path_prefix"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v bluetoothctl >/dev/null 2>&1 || { echo "missing bluetoothctl"; exit 1; }
  echo "ok"
  exit 0
fi

action="${1:-list}"

# Helper to get battery from upower
get_upower_battery() {
  local mac="$1"
  command -v upower >/dev/null 2>&1 || return 0
  local key="${mac//:/_}"
  local dev
  dev="$(upower -e 2>/dev/null | grep -i "bluez.*${key}" | head -n1 || true)"
  [[ -n "$dev" ]] || return 0
  upower -i "$dev" 2>/dev/null | sed -n 's/^\s*percentage:\s*//p' | head -n1
}

cache_file_path() {
  local uid runtime_dir
  uid="${UID:-$(id -u)}"
  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${uid}}"
  if [[ -d "$runtime_dir" ]]; then
    printf '%s/quickshell_bt_devices.cache\n' "$runtime_dir"
  else
    printf '/tmp/quickshell_bt_devices_%s.cache\n' "$uid"
  fi
}

cache_ttl_seconds=45

# Actions for pairing/connecting
case "$action" in
  scan-on)
    # Start scanning for nearby devices
    bluetoothctl --timeout 1 scan on &>/dev/null &
    echo "scanning=1"
    exit 0
    ;;
  scan-off)
    bluetoothctl scan off &>/dev/null || true
    echo "scanning=0"
    exit 0
    ;;
  discoverable-on)
    bluetoothctl discoverable on &>/dev/null || true
    bluetoothctl pairable on &>/dev/null || true
    echo "discoverable=1"
    exit 0
    ;;
  discoverable-off)
    bluetoothctl discoverable off &>/dev/null || true
    bluetoothctl pairable off &>/dev/null || true
    echo "discoverable=0"
    exit 0
    ;;
  pair)
    mac="${2:-}"
    [[ -n "$mac" ]] || { echo "error=no mac"; exit 1; }
    # Trust first to accept incoming pairing requests
    bluetoothctl trust "$mac" &>/dev/null || true
    # Attempt pairing
    if timeout 15 bluetoothctl pair "$mac" &>/dev/null; then
      echo "paired=1"
    else
      echo "paired=0"
    fi
    exit 0
    ;;
  connect)
    mac="${2:-}"
    [[ -n "$mac" ]] || { echo "error=no mac"; exit 1; }
    if bluetoothctl connect "$mac" &>/dev/null; then
      echo "connected=1"
    else
      echo "connected=0"
    fi
    exit 0
    ;;
  disconnect)
    mac="${2:-}"
    [[ -n "$mac" ]] || { echo "error=no mac"; exit 1; }
    bluetoothctl disconnect "$mac" &>/dev/null || true
    echo "disconnected=1"
    exit 0
    ;;
  remove)
    mac="${2:-}"
    [[ -n "$mac" ]] || { echo "error=no mac"; exit 1; }
    bluetoothctl remove "$mac" &>/dev/null || true
    echo "removed=1"
    exit 0
    ;;
  trust)
    mac="${2:-}"
    [[ -n "$mac" ]] || { echo "error=no mac"; exit 1; }
    bluetoothctl trust "$mac" &>/dev/null || true
    echo "trusted=1"
    exit 0
    ;;
  status)
    # Get controller status
    controller_info="$(bluetoothctl show 2>/dev/null || true)"
    powered="$(echo "$controller_info" | grep -oP 'Powered: \K\w+' || echo "no")"
    discoverable="$(echo "$controller_info" | grep -oP 'Discoverable: \K\w+' || echo "no")"
    pairable="$(echo "$controller_info" | grep -oP 'Pairable: \K\w+' || echo "no")"
    # Check if scanning (approximate)
    scanning="no"
    if pgrep -f "bluetoothctl.*scan" &>/dev/null; then
      scanning="yes"
    fi
    echo "powered=$powered"
    echo "discoverable=$discoverable"
    echo "pairable=$pairable"
    echo "scanning=$scanning"
    exit 0
    ;;
  list|*)
    # Continue to list devices below
    ;;
esac

cache_file="$(cache_file_path)"
now_epoch="$(date +%s)"
tmp_current="$(mktemp)"
tmp_cache_valid="$(mktemp)"
trap 'rm -f "$tmp_current" "$tmp_cache_valid"' EXIT

# Fetch all devices in a single call and process directly
devices_raw="$(bluetoothctl devices 2>/dev/null || true)"

while IFS= read -r dev_line; do
  [[ -n "$dev_line" ]] || continue
  if [[ "$dev_line" =~ ^Device[[:space:]]+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})[[:space:]]*(.*)$ ]]; then
    mac="${BASH_REMATCH[1]}"
    device_name="${BASH_REMATCH[3]}"

    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    name=""
    paired="no"
    connected="no"
    icon=""
    battery=""

    if [[ -n "$info" ]]; then
      while IFS= read -r iline; do
        iline="${iline#"${iline%%[![:space:]]*}"}" # strip leading whitespace
        case "$iline" in
          Name:*) [[ -z "$name" ]] && name="${iline#Name: }" ;;
          Alias:*) [[ -z "$name" ]] && name="${iline#Alias: }" ;;
          Paired:*) paired="${iline#Paired: }" ;;
          Connected:*) connected="${iline#Connected: }" ;;
          Icon:*) icon="${iline#Icon: }" ;;
          Battery\ Percentage:*)
            bval="${iline#Battery Percentage: }"
            bval="${bval//[()]/}"
            bval="${bval// /}"
            battery="$bval"
            ;;
        esac
      done <<< "$info"
    fi

    if [[ -z "$name" ]]; then
      name="${device_name:-$mac}"
    fi
    if [[ -z "$battery" ]]; then
      battery="$(get_upower_battery "$mac")"
    fi
    if [[ -n "$battery" && "$battery" != *"%"* ]]; then
      battery="${battery}%"
    fi

    printf '%s|%s|%s|%s|%s|%s\n' "$mac" "$name" "$paired" "$connected" "$icon" "$battery" >> "$tmp_current"
  fi
done <<< "$devices_raw"

if [[ -f "$cache_file" ]]; then
  while IFS='|' read -r ts mac name paired connected icon battery; do
    [[ -n "$ts" && -n "$mac" ]] || continue
    [[ "$ts" =~ ^[0-9]+$ ]] || continue
    if (( now_epoch - ts > cache_ttl_seconds )); then
      continue
    fi
    if [[ ! "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
      continue
    fi
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$ts" "$mac" "$name" "$paired" "$connected" "$icon" "$battery" >> "$tmp_cache_valid"
  done < "$cache_file"
fi

awk -F'|' 'NR == FNR { seen[$1] = 1; print; next } !($2 in seen) { print $2"|"$3"|"$4"|"$5"|"$6"|"$7 }' "$tmp_current" "$tmp_cache_valid"

{
  awk -F'|' -v now="$now_epoch" 'NF >= 6 { print now"|"$0 }' "$tmp_current"
  awk -F'|' 'NR == FNR { seen[$1] = 1; next } !($2 in seen) { print }' "$tmp_current" "$tmp_cache_valid"
} > "$cache_file"
