#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  ZENITH-SHELL — Multi-Distro Universal Installer
#  Repository: https://github.com/Lucas-Damasceno-dev/Zenith-Shell
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Visual Branding ──────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { printf "${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERR]${NC} %s\n" "$1"; exit 1; }

# ─── Self-Test Contract ───────────────────────────────────────────────────
if [[ "${1:-}" == "--self-test" ]]; then
  echo "ok"
  exit 0
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
TARGET_QS="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo -e "${CYAN}"
cat << "BANNER"
  ______            _ _   _         _____ _          _ _ 
 |___  /           (_) | | |       / ____| |        | | |
    / / ___ _ __  _ _| |_| |______| (___ | |__   ___| | |
   / / / _ \ '_ \| | | __| |______|___ \| '_ \ / _ \ | |
  / /_|  __/ | | | | | |_| |      ____) | | | |  __/ | |
 /_____\___|_| |_|_|_|\__|_|     |_____/|_| |_|\___|_|_|
BANNER
echo -e "${NC}"
info "Iniciando instalação do Zenith-Shell (Hyprland + Quickshell)..."

# ─── 1. Detecção de Distribuição ──────────────────────────────────────────
DISTRO="unknown"
if [ -f /etc/os-release ]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  DISTRO="${ID:-unknown}"
fi

info "Distribuição detectada: $DISTRO"

# ─── 2. Checagem / Sugestão de Dependências ──────────────────────────────
DEPS_PACMAN=(
  hyprland
  qt6-declarative
  qt6-5compat
  qt6-multimedia
  qt6-svg
  pipewire
  wireplumber
  playerctl
  socat
  jq
  grim
  slurp
  wl-clipboard
  cliphist
  brightnessctl
  libnotify
  imagemagick
  tesseract
  fd
  ripgrep
  papirus-icon-theme
  python
  python-requests
)

DEPS_DNF=(
  hyprland
  qt6-qtdeclarative
  qt6-qt5compat
  qt6-qtmultimedia
  qt6-qtsvg
  pipewire
  wireplumber
  playerctl
  socat
  jq
  grim
  slurp
  wl-clipboard
  cliphist
  brightnessctl
  libnotify
  ImageMagick
  tesseract
  fd-find
  ripgrep
  papirus-icon-theme
  python3
  python3-requests
)

DEPS_APT=(
  hyprland
  qml6-module-qtquick
  qml6-module-qtquick-layouts
  qml6-module-qtquick-controls
  qml6-module-qt5compat-graphicaleffects
  pipewire
  wireplumber
  playerctl
  socat
  jq
  grim
  slurp
  wl-clipboard
  brightnessctl
  libnotify-bin
  imagemagick
  tesseract-ocr
  fd-find
  ripgrep
  papirus-icon-theme
  python3
  python3-requests
)

install_dependencies() {
  case "$DISTRO" in
    arch|manjaro|endeavouros)
      info "Instalando dependências via pacman..."
      sudo pacman -S --needed --noconfirm "${DEPS_PACMAN[@]}" || warn "Algum pacote pode ter falhado na instalação."
      
      # AUR helper check para Quickshell, Matugen e Awww/Swww
      AUR_HELPER=""
      for helper in paru yay; do
        if command -v "$helper" >/dev/null 2>&1; then
          AUR_HELPER="$helper"
          break
        fi
      done
      
      if [ -n "$AUR_HELPER" ]; then
        info "AUR helper detectado ($AUR_HELPER). Instalando quickshell, matugen e awww..."
        "$AUR_HELPER" -S --needed --noconfirm quickshell-git matugen-bin awww || true
      else
        warn "Nenhum helper AUR (paru/yay) detectado."
        echo "Por favor instale manualmente: quickshell-git, matugen-bin, awww"
      fi
      ;;
    fedora)
      info "Instalando dependências via dnf..."
      sudo dnf install -y "${DEPS_DNF[@]}" || warn "Algum pacote pode ter falhado."
      info "Para Quickshell no Fedora, habilite o Copr: sudo dnf copr enable ryanabx/quickshell && sudo dnf install quickshell"
      ;;
    ubuntu|debian|pop)
      info "Instalando dependências via apt..."
      sudo apt-get update -y
      sudo apt-get install -y "${DEPS_APT[@]}" || warn "Algum pacote pode ter falhado."
      ;;
    nixos)
      info "NixOS detectado! Recomendamos importar o flake nativo (veja README.md)."
      ;;
    *)
      warn "Distribuição não identificada automaticamente. Verifique as dependências manuais no README.md."
      ;;
  esac
}

read -rp "Deseja que o instalador tente instalar os pacotes do sistema agora? [s/N]: " run_pkg
if [[ "$run_pkg" =~ ^[sSyY] ]]; then
  install_dependencies
fi

# ─── 3. Backup de Configurações Existentes ────────────────────────────────
backup_existing() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local backup_path="${target}.backup_${TIMESTAMP}"
    warn "Configuração existente encontrada em $target. Criando backup em $backup_path"
    mv "$target" "$backup_path"
    ok "Backup concluído: $backup_path"
  fi
}

backup_existing "$TARGET_HYPR"
backup_existing "$TARGET_QS"

# ─── 4. Instalação das Configurações ──────────────────────────────────────
info "Escolha o modo de instalação dos arquivos:"
echo "  1) Symlink (Recomendado para desenvolvedores/atualizações via git pull)"
echo "  2) Cópia estática (Recomendado para usuários casuais)"
read -rp "Opção [1/2] (padrão 1): " install_mode
install_mode="${install_mode:-1}"

mkdir -p "$(dirname "$TARGET_HYPR")"

if [ "$install_mode" -eq 1 ]; then
  info "Criando links simbólicos..."
  ln -sf "$SCRIPT_DIR/config/hypr" "$TARGET_HYPR"
  ln -sf "$SCRIPT_DIR/config/quickshell" "$TARGET_QS"
  ok "Symlinks criados com sucesso."
else
  info "Copiando arquivos..."
  cp -r "$SCRIPT_DIR/config/hypr" "$TARGET_HYPR"
  cp -r "$SCRIPT_DIR/config/quickshell" "$TARGET_QS"
  ok "Arquivos copiados com sucesso."
fi

# ─── 5. Configurar Permissões de Execução ─────────────────────────────────
info "Configurando permissões de scripts..."
chmod +x "$TARGET_HYPR/scripts/"*.sh 2>/dev/null || true
chmod +x "$TARGET_QS/scripts/"*/*.sh 2>/dev/null || true
chmod +x "$TARGET_QS/scripts/"*/*.py 2>/dev/null || true
ok "Permissões configuradas."

# ─── 6. Instalação dos Serviços Systemd do Usuário ────────────────────────
if command -v systemctl >/dev/null 2>&1; then
  read -rp "Deseja instalar e ativar os serviços systemd de usuário (quickshell, daemons)? [S/n]: " enable_services
  enable_services="${enable_services:-s}"
  if [[ "$enable_services" =~ ^[sSyY] ]]; then
    info "Instalando serviços systemd do usuário..."
    SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"
    cp -v "$SCRIPT_DIR/systemd/user/"*.service "$SYSTEMD_USER_DIR/" 2>/dev/null || true
    systemctl --user daemon-reload
    systemctl --user enable quickshell.service zenith-context-daemon.service zenith-cliphist.service 2>/dev/null || true
    ok "Serviços systemd habilitados."
  fi
fi

# ─── 7. Diretórios de Runtime e Dados ──────────────────────────────────────
info "Inicializando diretórios locais..."
mkdir -p "$HOME/.local/share/wallpapers"
mkdir -p "$HOME/.cache/quickshell/matugen"
mkdir -p "$HOME/.cache/wallpaper"

ok "Zenith-Shell instalado com sucesso!"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Próximos passos:${NC}"
echo -e "  1. Inicie ou reinicie a sessão Hyprland: ${CYAN}Hyprland${NC}"
echo -e "  2. Para alternar papéis de parede e tema dinâmico: ${CYAN}SUPER + SHIFT + W${NC}"
echo -e "  3. Para abrir o lançador rápido: ${CYAN}SUPER (tecla Windows)${NC} ou ${CYAN}SUPER + Space${NC}"
echo -e "  4. Para ver o Cheat Sheet de atalhos: ${CYAN}SUPER + /${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
