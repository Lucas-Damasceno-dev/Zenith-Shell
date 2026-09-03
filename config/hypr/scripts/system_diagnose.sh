#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    command -v journalctl >/dev/null 2>&1 || { echo "missing journalctl"; exit 1; }
    command -v dmesg >/dev/null 2>&1 || { echo "missing dmesg"; exit 1; }
    command -v ps >/dev/null 2>&1 || { echo "missing ps"; exit 1; }
    echo "ok"
    exit 0
fi

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_DIR="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/system_diagnose_$(date +%Y%m%d_%H%M%S)_XXXXXX")"
chmod 0700 "$LOG_DIR"
mkdir -p "$LOG_DIR/quickshell_crashes"

echo -e "${BLUE}=== Iniciando Coleta de Logs em $LOG_DIR ===${NC}"

# 1. NixOS / Systemd Logs (Últimos 30 minutos, erros e avisos)
echo -e "${YELLOW}[1/5] Coletando logs do Systemd (NixOS)...${NC}"
journalctl -b 0 --since "30 min ago" -p err..warn --no-pager > "$LOG_DIR/systemd_errors.log"
journalctl -b 0 -u hyprland --no-pager > "$LOG_DIR/hyprland_systemd.log" 2>/dev/null || true

# 2. Hyprland Logs e Crash Reports
echo -e "${YELLOW}[2/5] Coletando logs do Hyprland...${NC}"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    cp "/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" "$LOG_DIR/hyprland_current.log" 2>/dev/null || true
fi
# Pega os 2 crash reports mais recentes
ls -t ~/.cache/hyprland/hyprlandCrashReport*.txt 2>/dev/null | head -n 2 | xargs -I {} cp {} "$LOG_DIR/" || true

# 3. Quickshell Logs
echo -e "${YELLOW}[3/5] Coletando logs do Quickshell...${NC}"
journalctl --user -u quickshell --since "30 min ago" --no-pager > "$LOG_DIR/quickshell_user.log"
# Busca o log da instância mais recente
find /run/user/$(id -u)/quickshell/by-id/ -name "log.log" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -f2- -d" " | xargs -I {} cp {} "$LOG_DIR/quickshell_latest_instance.log" 2>/dev/null || true
# Crash reports do Quickshell
ls -dt ~/.cache/quickshell/crashes/* 2>/dev/null | head -n 2 | xargs -I {} cp -r {} "$LOG_DIR/quickshell_crashes/" 2>/dev/null || true

# 4. Kernel / Hardware
echo -e "${YELLOW}[4/5] Coletando dmesg (Kernel)...${NC}"
dmesg -T | tail -n 200 > "$LOG_DIR/kernel_dmesg.log"

# 5. Estado do Sistema (IPC e Processos)
echo -e "${YELLOW}[5/5] Coletando estado dos processos...${NC}"
ps aux | grep -E "Hyprland|quickshell|ipc" > "$LOG_DIR/process_state.log"

echo -e "${GREEN}=== Coleta Concluída! ===${NC}"
echo -e "Os logs foram salvos em: ${BLUE}$LOG_DIR${NC}"
echo -e "Resumo de Erros Críticos (Últimas 10 linhas do Journal):"
tail -n 10 "$LOG_DIR/systemd_errors.log"
