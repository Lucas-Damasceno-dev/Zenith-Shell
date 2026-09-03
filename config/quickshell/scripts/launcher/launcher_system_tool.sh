#!/usr/bin/env bash
set -euo pipefail

user_nix_profile=""
if [[ -n "${HOME:-}" ]]; then
  user_nix_profile="${HOME}/.nix-profile/bin"
fi
export PATH="/run/current-system/sw/bin${user_nix_profile:+:${user_nix_profile}}:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v jq >/dev/null 2>&1 || { echo "missing jq"; exit 1; }
  command -v expect >/dev/null 2>&1 || { echo "missing expect"; exit 1; }
  echo "ok"
  exit 0
fi

cmd="${1:-}"
BTCTL_BIN="${BTCTL_BIN:-bluetoothctl}"
RFKILL_BIN="${RFKILL_BIN:-rfkill}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/launcher_system_bluetooth.sh
source "$script_dir/../lib/launcher_system_bluetooth.sh"

wifi_status() {
  local enabled_raw active_line ssid signal enabled rest
  enabled_raw="$(nmcli -t -f WIFI general 2>/dev/null | head -n1 || true)"
  case "${enabled_raw,,}" in
    enabled|on|yes|sim|true) enabled=1 ;;
    *) enabled=0 ;;
  esac
  active_line="$(nmcli -t -f active,ssid,signal dev wifi list 2>/dev/null | sed -n '/^\(yes\|sim\|\*\):/p' | head -n1)"
  ssid=""
  signal=0
  if [[ -n "$active_line" ]]; then
    signal="${active_line##*:}"
    rest="${active_line%:*}"
    ssid="${rest#*:}"
    ssid="${ssid//\\:/:}"
    ssid="${ssid//\\\\/\\}"
  fi
  jq -cn \
    --argjson enabled "$enabled" \
    --arg ssid "$ssid" \
    --argjson signal "${signal:-0}" \
    '{enabled: ($enabled == 1), ssid: $ssid, signal: $signal}'
}

wifi_toggle() {
  local action="${1:-toggle}" state current
  case "$action" in
    on|off)
      state="$action"
      ;;
    *)
      current="$(nmcli -t -f WIFI general 2>/dev/null | head -n1 || true)"
      if [[ "${current,,}" == "enabled" || "${current,,}" == "on" || "${current,,}" == "yes" || "${current,,}" == "sim" ]]; then
        state="off"
      else
        state="on"
      fi
      ;;
  esac
  nmcli radio wifi "$state"
}

window_memory() {
  local pid="${1:-}"
  [[ -n "$pid" ]] || exit 0
  local rss_kb=0 total_kb=0 key val

  if [[ -r "/proc/$pid/status" ]]; then
    while IFS=':' read -r key val; do
      case "$key" in
        VmRSS)
          val="${val//[[:space:]]/}"
          val="${val%kB}"
          [[ "$val" =~ ^[0-9]+$ ]] && rss_kb="$val"
          break
          ;;
      esac
    done < "/proc/$pid/status"
  fi

  if [[ -r /proc/meminfo ]]; then
    while IFS=':' read -r key val; do
      case "$key" in
        MemTotal)
          val="${val//[[:space:]]/}"
          val="${val%kB}"
          [[ "$val" =~ ^[0-9]+$ ]] && total_kb="$val"
          break
          ;;
      esac
    done < /proc/meminfo
  fi

  [[ "$rss_kb" =~ ^[0-9]+$ ]] || rss_kb=0
  [[ "$total_kb" =~ ^[0-9]+$ ]] || total_kb=0
  jq -cn \
    --argjson rssKb "$rss_kb" \
    --argjson totalKb "$total_kb" \
    '{
      rssKb: $rssKb,
      rssMiB: (($rssKb / 1024) | floor),
      ratio: (if $totalKb > 0 then ($rssKb / $totalKb) else 0 end)
    }'
}

case "$cmd" in
  wifi-status)
    wifi_status
    ;;
  wifi-toggle)
    wifi_toggle "${2:-toggle}"
    ;;
  bt-status)
    bt_status
    ;;
  bt-toggle)
    bt_toggle "${2:-toggle}"
    ;;
  bt-device)
    bt_device "${2:-}" "${3:-}" "${4:-}"
    ;;
  bt-pairable)
    bt_pairable "${2:-on}"
    ;;
  bt-discoverable)
    bt_discoverable "${2:-on}"
    ;;
  bt-scan)
    bt_scan "${2:-on}"
    ;;
  bt-open-manager)
    bt_open_manager
    ;;
  window-memory)
    window_memory "${2:-}"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
