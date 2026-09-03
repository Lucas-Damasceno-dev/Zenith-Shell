#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

user_name="${USER:-$(id -un)}"
home_dir="${HOME:-}"
if [[ -z "$home_dir" ]]; then
    home_dir="$(awk -F: -v user="$user_name" '$1==user {print $6; exit}' /etc/passwd 2>/dev/null || true)"
    if [[ -z "$home_dir" ]]; then
        home_dir="/home/$user_name"
    fi
    export HOME="$home_dir"
fi

export PATH="$home_dir/.nix-profile/bin:/run/current-system/sw/bin:${PATH:-}"

query="${*:-}"
[[ -n "$query" ]] || exit 0

fallback() {
    local q="${query,,}"
    if [[ "$q" == *"rebuild"* || "$q" == *"nixos"* ]]; then
        echo "sudo nixos-rebuild switch"
    elif [[ "$q" == *"home-manager"* || "$q" == *"hm"* ]]; then
        echo "home-manager switch"
    elif [[ "$q" == *"log"* || "$q" == *"quickshell"* ]]; then
        echo "journalctl --user -u quickshell --no-pager -n 120"
    elif [[ "$q" == *"wifi"* || "$q" == *"rede"* ]]; then
        echo "nmcli device status"
    elif [[ "$q" == *"audio"* || "$q" == *"som"* ]]; then
        echo "wpctl status"
    else
        echo "echo \"$query\""
    fi
}

if command -v ollama >/dev/null 2>&1; then
    suggestion="$(
        timeout 8s ollama run llama3.2 "Responda apenas um comando shell seguro para Linux: ${query}" 2>/dev/null \
            | tail -n 1 \
            | tr -d '\r' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"
    if [[ -n "$suggestion" ]]; then
        echo "$suggestion"
        exit 0
    fi
fi

echo "__NO_OLLAMA__:$(fallback)"
