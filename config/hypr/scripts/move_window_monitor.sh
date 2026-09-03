#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

direction="${1:-next}"
if [[ "$direction" != "next" && "$direction" != "prev" ]]; then
    direction="next"
fi

if ! command -v jq >/dev/null 2>&1; then
    notify-send -a "Hyprland" "Move window" "jq não encontrado"
    exit 1
fi

active_json="$(hyprctl -j activewindow 2>/dev/null || true)"
monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"

if [[ -z "$active_json" || -z "$monitors_json" ]]; then
    notify-send -a "Hyprland" "Move window" "Falha ao obter estado do Hyprland"
    exit 0
fi

read -r addr ws_id count current_idx < <(
    jq -r -s '
        .[0] as $act | .[1] as $mons |
        ($act.address // "") as $a |
        ($act.workspace.id // "") as $w |
        ($mons | length) as $c |
        ([ $mons | to_entries[] | select(.value.activeWorkspace.id == $w) | .key ][0] //
         [ $mons | to_entries[] | select(.value.focused == true) | .key ][0] // 0) as $idx |
        "\($a) \($w) \($c) \($idx)"
    ' <(printf '%s' "$active_json") <(printf '%s' "$monitors_json") 2>/dev/null || echo ""
)

if [[ -z "$addr" || -z "$ws_id" ]]; then
    notify-send -a "Hyprland" "Move window" "Nenhuma janela ativa"
    exit 0
fi
if [[ "$addr" != 0x* ]]; then
    addr="0x${addr}"
fi

if [[ -z "$count" || "$count" -lt 2 ]]; then
    notify-send -a "Hyprland" "Move window" "Apenas um monitor disponível"
    exit 0
fi

[[ -n "$current_idx" ]] || current_idx=0

if [[ "$direction" == "next" ]]; then
    target_idx=$(( (current_idx + 1) % count ))
else
    target_idx=$(( (current_idx - 1 + count) % count ))
fi

read -r target_name target_ws < <(
    printf '%s' "$monitors_json" | jq -r --argjson idx "$target_idx" '
        .[$idx] | "\(.name // "") \(.activeWorkspace.id // "")"
    ' 2>/dev/null || echo ""
)

if [[ -z "$target_name" || -z "$target_ws" ]]; then
    notify-send -a "Hyprland" "Move window" "Monitor alvo inválido"
    exit 1
fi

hyprctl --batch "dispatch movetoworkspace ${target_ws},address:${addr} ; dispatch workspace ${target_ws}" >/dev/null 2>&1 || true
notify-send -a "Hyprland" "Move window" "Janela enviada para ${target_name}"

