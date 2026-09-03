#!/usr/bin/env bash
# launcher_recent_files.sh — Parse ~/.local/share/recently-used.xbel and output recent files
# Usage: launcher_recent_files.sh [search_term]
set -euo pipefail

export PATH="${HOME}/.nix-profile/bin:/run/current-system/sw/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    [[ -f "${HOME}/.local/share/recently-used.xbel" ]] && echo "ok" || echo "ok"
    exit 0
fi

XBEL="${HOME}/.local/share/recently-used.xbel"
TERM="${1:-}"
MAX=30

[[ -f "$XBEL" ]] || exit 0

python3 - "$XBEL" "$TERM" "$MAX" << 'PYEOF'
import os
import sys
import urllib.parse
import xml.etree.ElementTree as ET

xbel_file = sys.argv[1]
term = sys.argv[2].lower() if len(sys.argv) > 2 else ""
max_items = int(sys.argv[3]) if len(sys.argv) > 3 else 30

if not os.path.exists(xbel_file):
    sys.exit(0)

try:
    tree = ET.parse(xbel_file)
    root = tree.getroot()
    items = []
    for bm in root.findall("bookmark"):
        href = bm.get("href", "")
        visited = bm.get("visited", bm.get("modified", ""))
        if href.startswith("file:///"):
            raw_path = href[7:]
            decoded_path = urllib.parse.unquote(raw_path)
            items.append((visited, decoded_path))

    # Sort by visited descending
    items.sort(key=lambda x: x[0], reverse=True)

    count = 0
    for _, path in items:
        if not os.path.exists(path):
            continue
        if term:
            base = os.path.basename(path).lower()
            if term not in base:
                continue
        print(path)
        count += 1
        if count >= max_items:
            break
except Exception:
    pass
PYEOF
