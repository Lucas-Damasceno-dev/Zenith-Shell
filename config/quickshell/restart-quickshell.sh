#!/usr/bin/env bash
# restart-quickshell.sh - Flush cache and restart Quickshell
# Run as your normal user (not root):  ./restart-quickshell.sh

set -euo pipefail

echo ">> Stopping quickshell..."
systemctl --user stop quickshell 2>/dev/null || true

echo ">> Clearing quickshell cache..."
rm -rf ~/.cache/quickshell

echo ">> Starting quickshell..."
systemctl --user start quickshell

echo ">> Done. Quickshell restarted with fresh ColorScheme."
systemctl --user status quickshell --no-pager || true
