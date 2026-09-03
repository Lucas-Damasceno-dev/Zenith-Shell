#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" && "${1:-}" == "--self-test" ]]; then
  echo "ok"
  exit 0
fi

bt_show_field() {
  local field="${1:-}"
  local out
  out="$("$BTCTL_BIN" show || true)"
  if [[ -z "$out" ]]; then return 0; fi
  printf '%s\n' "$out" | sed -n "s/^[[:space:]]*${field}: //p" | head -n1 || true
}

bt_status() {
  local powered pairable discoverable discovering
  powered="$(bt_show_field Powered)"
  pairable="$(bt_show_field Pairable)"
  discoverable="$(bt_show_field Discoverable)"
  discovering="$(bt_show_field Discovering)"
  jq -cn \
    --arg powered "$powered" \
    --arg pairable "$pairable" \
    --arg discoverable "$discoverable" \
    --arg discovering "$discovering" \
    '{
      enabled: (($powered | ascii_downcase) == "yes"),
      pairable: (($pairable | ascii_downcase) == "yes"),
      discoverable: (($discoverable | ascii_downcase) == "yes"),
      discovering: (($discovering | ascii_downcase) == "yes")
    }'
}

bt_power_state() {
  local powered
  powered="$(bt_show_field Powered)"
  case "${powered,,}" in
    yes) printf 'on\n' ;;
    no) printf 'off\n' ;;
    *) printf '\n' ;;
  esac
}

bt_flag_state() {
  local field="${1:-}"
  local value
  value="$(bt_show_field "$field")"
  case "${value,,}" in
    yes) printf 'on\n' ;;
    no) printf 'off\n' ;;
    *) printf '\n' ;;
  esac
}

ensure_bt_unblocked() {
  command -v "$RFKILL_BIN" >/dev/null 2>&1 || return 0
  "$RFKILL_BIN" unblock bluetooth || true
}

ensure_blueman_agent() {
  command -v blueman-applet >/dev/null 2>&1 || return 1

  if ! pgrep -f '[/]blueman-applet' >/dev/null 2>&1; then
    nohup blueman-applet >/dev/null 2>&1 &
    sleep 0.4
  fi

  return 0
}

open_blueman_manager() {
  command -v blueman-manager >/dev/null 2>&1 || return 1

  if ! pgrep -f '[/]blueman-manager' >/dev/null 2>&1; then
    nohup blueman-manager >/dev/null 2>&1 &
  fi

  return 0
}

ensure_bt_agent() {
  ensure_blueman_agent || true

  "$BTCTL_BIN" agent KeyboardDisplay >/dev/null 2>&1 || \
    "$BTCTL_BIN" agent DisplayYesNo >/dev/null 2>&1 || \
    "$BTCTL_BIN" agent NoInputNoOutput >/dev/null 2>&1 || true
  "$BTCTL_BIN" default-agent >/dev/null 2>&1 || true
  return 0
}

bt_pair_with_pin() {
  local mac="${1:-}"
  local pin="${2:-}"

  [[ -n "$mac" && -n "$pin" ]] || return 1
  command -v expect >/dev/null 2>&1 || return 1

  BT_MAC="$mac" BT_PIN="$pin" expect <<'EOF' >/dev/null 2>&1
set timeout 20
spawn bluetoothctl
expect -re {#}
send "agent KeyboardDisplay\r"
expect -re {#}
send "default-agent\r"
expect -re {#}
send "pair $env(BT_MAC)\r"
expect {
  -re {Enter PIN code:|Enter passkey:|Request PIN code:|PIN code:} {
    send -- "$env(BT_PIN)\r"
    exp_continue
  }
  -re {Confirm passkey.*|Confirm pairing.*|Accept pairing.*|Authorize service.*} {
    send -- "yes\r"
    exp_continue
  }
  -re {Pairing successful|Connection successful} { exit 0 }
  -re {Failed to pair|Authentication Failed|Authentication failed|Not Available|Rejected|Cancelled|Canceled} { exit 1 }
  timeout { exit 1 }
}
EOF
}

ensure_bt_powered_on() {
  local current

  current="$(bt_power_state)"
  if [[ "$current" == "on" ]]; then
    return 0
  fi

  ensure_bt_unblocked
  if ! "$BTCTL_BIN" power on; then
    true
  fi

  wait_for_bt_power_state "on" 50 0.1 || return 1
}

wait_for_bt_power_state() {
  local desired="${1:-}"
  local attempts="${2:-50}"
  local delay="${3:-0.1}"
  local current i

  for ((i = 0; i < attempts; i++)); do
    current="$(bt_power_state)"
    if [[ "$current" == "$desired" ]]; then
      return 0
    fi
    sleep "$delay"
  done

  return 1
}

wait_for_bt_flag_state() {
  local field="${1:-}"
  local desired="${2:-}"
  local attempts="${3:-50}"
  local delay="${4:-0.1}"
  local current i

  for ((i = 0; i < attempts; i++)); do
    current="$(bt_flag_state "$field")"
    if [[ "$current" == "$desired" ]]; then
      return 0
    fi
    sleep "$delay"
  done

  return 1
}

bt_set_flag() {
  local command_name="${1:-}"
  local field_name="${2:-}"
  local action="${3:-}"

  [[ -n "$command_name" && -n "$field_name" ]] || return 1
  case "$action" in
    on|off) ;;
    *) return 1 ;;
  esac

  if [[ "$action" == "on" ]]; then
    ensure_bt_powered_on || return 1
  fi

  if ! "$BTCTL_BIN" "$command_name" "$action" >/dev/null 2>&1; then
    return 1
  fi

  wait_for_bt_flag_state "$field_name" "$action" 50 0.1
}

bt_device_state() {
  local mac="${1:-}"
  local field="${2:-}"
  local value

  value="$("$BTCTL_BIN" info "$mac" 2>/dev/null | sed -n "s/^\\s*${field}: //p" | head -n1 || true)"
  case "${value,,}" in
    yes) printf 'yes\n' ;;
    no) printf 'no\n' ;;
    *) printf '\n' ;;
  esac
}

wait_for_bt_device_state() {
  local mac="${1:-}"
  local field="${2:-}"
  local desired="${3:-}"
  local attempts="${4:-25}"
  local delay="${5:-0.1}"
  local current i

  for ((i = 0; i < attempts; i++)); do
    current="$(bt_device_state "$mac" "$field")"
    if [[ "$current" == "$desired" ]]; then
      return 0
    fi
    sleep "$delay"
  done

  return 1
}

bt_toggle() {
  local action="${1:-toggle}" state current
  case "$action" in
    on|off)
      state="$action"
      ;;
    *)
      current="$(bt_show_field Powered)"
      if [[ "${current,,}" == "yes" ]]; then
        state="off"
      else
        state="on"
      fi
      ;;
  esac

  if [[ "$state" == "on" ]]; then
    ensure_bt_powered_on || return 1
    "$BTCTL_BIN" pairable on >/dev/null 2>&1 || true
    "$BTCTL_BIN" discoverable on >/dev/null 2>&1 || true
    "$BTCTL_BIN" scan on >/dev/null 2>&1 || true
    ensure_bt_agent
  else
    "$BTCTL_BIN" scan off >/dev/null 2>&1 || true
    if ! "$BTCTL_BIN" power "$state" >/dev/null 2>&1; then
      true
    fi
    wait_for_bt_power_state "$state" 50 0.1 || return 1
  fi
}

bt_device() {
  local action="${1:-}"
  local mac="${2:-}"
  local pin="${3:-}"
  local paired_before
  [[ -n "$action" && -n "$mac" ]] || exit 1

  case "$action" in
    connect)
      ensure_bt_powered_on || return 1
      ensure_bt_agent || true
      if [[ "$(bt_device_state "$mac" Connected)" == "yes" ]]; then
        return 0
      fi
      "$BTCTL_BIN" trust "$mac" >/dev/null 2>&1 || true
      if ! "$BTCTL_BIN" connect "$mac" >/dev/null 2>&1; then
        open_blueman_manager >/dev/null 2>&1 || true
        echo "error: connect command failed"
        return 1
      fi
      wait_for_bt_device_state "$mac" Connected yes 120 0.1 || {
        open_blueman_manager >/dev/null 2>&1 || true
        echo "error: device did not connect"
        return 1
      }
      ;;
    disconnect)
      if ! "$BTCTL_BIN" disconnect "$mac" >/dev/null 2>&1; then
        echo "error: disconnect command failed"
        return 1
      fi
      wait_for_bt_device_state "$mac" Connected no 80 0.1 || {
        echo "error: device did not disconnect"
        return 1
      }
      ;;
    pair)
      ensure_bt_powered_on || return 1
      ensure_bt_agent
      "$BTCTL_BIN" scan off >/dev/null 2>&1 || true

      paired_before="$(bt_device_state "$mac" Paired)"
      if [[ "$paired_before" != "yes" ]]; then
        if [[ -n "$pin" ]]; then
          if ! bt_pair_with_pin "$mac" "$pin"; then
            open_blueman_manager >/dev/null 2>&1 || true
            echo "error: pairing failed (check PIN/confirmation)"
            return 1
          fi
        elif ! "$BTCTL_BIN" pair "$mac" >/dev/null 2>&1; then
          open_blueman_manager >/dev/null 2>&1 || true
          echo "error: pairing failed (check PIN/confirmation)"
          return 1
        fi
      fi

      "$BTCTL_BIN" trust "$mac" >/dev/null 2>&1 || true
      wait_for_bt_device_state "$mac" Paired yes 150 0.1 || {
        open_blueman_manager >/dev/null 2>&1 || true
        echo "error: device not paired"
        return 1
      }
      ;;
    trust)
      ensure_bt_powered_on || return 1
      "$BTCTL_BIN" trust "$mac" >/dev/null
      ;;
    *)
      exit 1
      ;;
  esac
}

bt_pairable() {
  local action="${1:-on}"
  bt_set_flag pairable Pairable "$action"
}

bt_discoverable() {
  local action="${1:-on}"
  bt_set_flag discoverable Discoverable "$action"
}

bt_scan() {
  local action="${1:-on}"

  case "$action" in
    on|off) ;;
    *) return 1 ;;
  esac

  if [[ "$action" == "on" ]]; then
    ensure_bt_powered_on || return 1
  fi

  if ! "$BTCTL_BIN" scan "$action" >/dev/null 2>&1; then
    return 1
  fi

  wait_for_bt_flag_state Discovering "$action" 40 0.1 || true
}

bt_open_manager() {
  ensure_bt_powered_on || return 1
  ensure_bt_agent || true
  open_blueman_manager
}
