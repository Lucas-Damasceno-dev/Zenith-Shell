#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

workspace_name="chat"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

chat_window_exists() {
    hyprctl -j clients 2>/dev/null \
        | jq -e '.[] | select((.class == "scratchpad-chat") or (.workspace.name == "special:chat"))' >/dev/null 2>&1
}

launch_chat() {
    if command -v vesktop >/dev/null 2>&1; then
        vesktop --class scratchpad-chat >/dev/null 2>&1 &
        return 0
    fi
    if command -v discord >/dev/null 2>&1; then
        discord --class scratchpad-chat >/dev/null 2>&1 &
        return 0
    fi
    if command -v slack >/dev/null 2>&1; then
        slack --class scratchpad-chat >/dev/null 2>&1 &
        return 0
    fi
    return 1
}

if chat_window_exists; then
    hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null || true
    exit 0
fi

if ! launch_chat; then
    notify-send -a "Hyprland" "Scratchpad Chat" "Nenhum app de chat suportado encontrado (vesktop/discord/slack)."
    exit 1
fi

sleep 0.25
hyprctl dispatch togglespecialworkspace "$workspace_name" >/dev/null || true
