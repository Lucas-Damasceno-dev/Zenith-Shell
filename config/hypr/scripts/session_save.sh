#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

out_file="${1:-${HOME}/.cache/hypr-session.json}"
mkdir -p "$(dirname "$out_file")"

if ! command -v jq >/dev/null 2>&1; then
    notify-send -a "Hyprland" "Session save" "jq não encontrado"
    exit 1
fi

clients_json="$(hyprctl -j clients 2>/dev/null || echo '[]')"
active_ws="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // 1' 2>/dev/null || echo 1)"

printf '%s' "$clients_json" | jq --argjson active "$active_ws" '
{
  savedAt: (now | todate),
  activeWorkspace: $active,
  windows: [
    .[] | {
      class: (.class // ""),
      title: (.title // ""),
      workspace: (.workspace.id // 1),
      floating: (.floating // false)
    }
  ]
}
' > "$out_file"

notify-send -a "Hyprland" "Session save" "Layout salvo em $(basename "$out_file")"

