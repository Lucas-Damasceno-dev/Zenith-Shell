#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

state_file="${1:-${HOME}/.cache/hypr-session.json}"
if [[ ! -f "$state_file" ]]; then
    notify-send -a "Hyprland" "Session restore" "Snapshot não encontrado"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    notify-send -a "Hyprland" "Session restore" "jq não encontrado"
    exit 1
fi

declare -A class_ws_list
declare -A class_flo_list

while IFS=$'\t' read -r cls ws flo; do
    [[ -z "$cls" ]] && continue
    class_ws_list["$cls"]="${class_ws_list["$cls"]:+${class_ws_list["$cls"]} }$ws"
    class_flo_list["$cls"]="${class_flo_list["$cls"]:+${class_flo_list["$cls"]} }$flo"
done < <(jq -r '.windows[] | [.class, (.workspace|tostring), (.floating|tostring)] | @tsv' "$state_file")

current_clients="$(hyprctl -j clients 2>/dev/null || echo '[]')"
moved=0

while IFS=$'\t' read -r addr cls floating_now; do
    [[ -z "$addr" || -z "$cls" ]] && continue
    list="${class_ws_list["$cls"]:-}"
    [[ -n "$list" ]] || continue
    target_ws="${list%% *}"
    if [[ "$list" == *" "* ]]; then
        class_ws_list["$cls"]="${list#* }"
    else
        unset 'class_ws_list["$cls"]'
    fi

    flo_list="${class_flo_list["$cls"]:-}"
    target_flo="${flo_list%% *}"
    if [[ "$flo_list" == *" "* ]]; then
        class_flo_list["$cls"]="${flo_list#* }"
    else
        unset 'class_flo_list["$cls"]'
    fi

    [[ "$addr" == 0x* ]] || addr="0x${addr}"

    hyprctl dispatch movetoworkspace "${target_ws},address:${addr}" >/dev/null || true

    if [[ "$target_flo" == "true" && "$floating_now" != "true" ]]; then
        hyprctl dispatch togglefloating "address:${addr}" >/dev/null || true
    fi
    moved=$((moved + 1))
done < <(printf '%s' "$current_clients" | jq -r '.[] | [.address, (.class // ""), ((.floating // false)|tostring)] | @tsv')

active_ws="$(jq -r '.activeWorkspace // empty' "$state_file")"
if [[ -n "$active_ws" ]]; then
    hyprctl dispatch workspace "$active_ws" >/dev/null || true
fi

notify-send -a "Hyprland" "Session restore" "Janelas reposicionadas: ${moved}"

