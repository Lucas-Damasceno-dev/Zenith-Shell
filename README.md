<div align="center">

# ⚡ ZENITH-SHELL
### Next-Generation Linux Desktop Shell & Rice
*Powered by **Hyprland** & **Quickshell (Qt6 / QML)***

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00c8ff.svg)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-Qt6_QML-green.svg)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Multi-Distro](https://img.shields.io/badge/Supported-Arch%20%7C%20Fedora%20%7C%20Ubuntu%20%7C%20NixOS-orange.svg)](#-instala%C3%A7%C3%A3o)

**Zenith-Shell** é uma interface de desktop moderna, modular, reativa e de alta performance construída sobre Wayland. Inspirada no ecossistema Material You, traz sincronização dinâmica de cores gerada pelo papel de parede atual via Matugen.

</div>

---

## 🌟 Principais Recursos

- 🎨 **Sincronização Dinâmica de Cores (Material You):** Extrai a paleta tonal do wallpaper usando **Matugen** com suporte a animações suaves de transição.
- 🚀 **Quickshell Engine (Qt6/QML):** Zero electron, carregamento instantâneo, renderização acelerada por GPU e consumo mínimo de recursos.
- 🔍 **Launcher Inteligente & Omnibar:** Lançamento de aplicativos, conversão de moedas/unidades, busca na web, clipboard history, OCR integrado e busca de projetos de código.
- 🎛️ **Overlays & Popups Contextuais:**
  - 🔊 Volume Mixer por aplicativo e seletor de saída/entrada (Pipewire).
  - 🔋 Battery Health & Monitor de consumo de energia (UPower/TLP).
  - 🌐 Network & Bluetooth manager reativo.
  - 📅 Calendário de produtividade e Quick Notes.
  - 📊 Monitor de telemetria de sistema (CPU, RAM, GPU, Disco).
- 🖥️ **Multi-Monitor & Hotplug Inteligente:** Daemons dedicados para detecção dinâmica de displays externos, posicionamento automático e preservação de workspaces.
- 🪟 **Janelas & Scratchpads:** Scratchpad de terminal do sistema, chat e terminal de IA integrados com atalhos dedicados.
- 🐧 **100% Distro-Agnostic:** Funciona no Arch Linux, Fedora, Ubuntu/Debian, NixOS e qualquer distribuição com suporte a Wayland.

---

## 📦 Arquitetura do Projeto

```text
Zenith-Shell/
├── install.sh                  # Instalador universal multi-distro
├── PKGBUILD                    # Pacote nativo para Arch Linux (AUR)
├── flake.nix                   # Suporte nativo Nix Flake & Home Manager
├── nix/
│   └── home-manager.nix        # Módulo declarativo para Home Manager
├── config/
│   ├── hypr/                   # Configurações Hyprland (hyprland.conf, idle, lock)
│   │   └── scripts/            # Scripts de automação desktop (35+ utilitários)
│   └── quickshell/             # Shell QML modular (Bar, Dock, Popups, Overlays)
└── systemd/user/               # Units systemd para gerenciar daemons em background
```

---

## 🚀 Instalação

### Opção 1: Instalador Universal (Arch, Fedora, Ubuntu, Debian)

```bash
git clone https://github.com/Lucas-Damasceno-dev/Zenith-Shell.git
cd Zenith-Shell
./install.sh
```
*O instalador detectará seu gerenciador de pacotes (`pacman`, `dnf`, `apt`), instalará as dependências e configurará os links simbólicos ou arquivos em `~/.config/hypr` e `~/.config/quickshell`.*

---

### Opção 2: Arch Linux (AUR / PKGBUILD)

```bash
cd Zenith-Shell
makepkg -si
zenith-shell-installer
```

Ou com `paru` / `yay`:
```bash
paru -S zenith-shell-git
```

---

### Opção 3: NixOS / Home Manager (Flake)

No seu `flake.nix`:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zenith-shell.url = "github:Lucas-Damasceno-dev/Zenith-Shell";
  };

  outputs = { self, nixpkgs, zenith-shell, ... }: {
    # No seu Home Manager:
    homeConfigurations."usuario" = home-manager.lib.homeManagerConfiguration {
      modules = [
        zenith-shell.homeManagerModules.default
        {
          programs.zenith-shell = {
            enable = true;
            terminal = "kitty";
            browser = "brave";
          };
        }
      ];
    };
  };
}
```

---

## ⌨️ Atalhos Principais (Cheatsheet)

| Atalho | Ação |
| :--- | :--- |
| `SUPER` | Abre o Lançador Rápido (Launcher) |
| `SUPER + Space` | Alterna a Visão Geral de Janelas (Overview) |
| `SUPER + Q` | Abre o Terminal (`kitty`) |
| `SUPER + W` | Abre o Navegador Web (`brave`) |
| `SUPER + E` | Gerenciador de Arquivos (`thunar`) |
| `SUPER + C` | Fecha a Janela Ativa |
| `SUPER + V` | Alterna modo Flutuante (Floating) |
| `SUPER + F` | Alterna Modo Tela Cheia (Fullscreen) |
| `SUPER + Tab` | Seletor de Workspaces |
| `SUPER + M` | Menu de Mídia / Playerctl |
| `SUPER + S` | Hub de Utilitários |
| `SUPER + /` | Cheat Sheet de Teclas e Comandos |
| `SUPER + Return` | Scratchpad Terminal do Sistema |
| `SUPER + N` | Bloco de Notas Rápidas (Quick Note) |
| `SUPER + T` | OCR na Tela (Extrair texto selecionado) |
| `SUPER + SHIFT + W` | Próximo Wallpaper & Atualização de Tema Dinâmico |
| `SUPER + CTRL + W` | Wallpaper Anterior |
| `SUPER + ALT + W` | Salvar Wallpaper atual como Favorito |
| `Print` | Screenshot de Tela Cheia |
| `SUPER + ALT + Print` | Screenshot de Região Selecionada |
| `SUPER + R` | Alternar Gravação de Tela (Região) |
| `SUPER + L` | Bloquear Tela (`hyprlock`) |

---

## 🛠️ Personalização

- **Monitores:** Crie o arquivo `~/.config/hypr/monitors.conf` para sobrescrever as taxas de atualização e resoluções dos seus monitores.
- **Wallpapers:** Coloque suas imagens em `~/.local/share/wallpapers/`. O script `random-wallpaper.sh` selecionará automaticamente e extrairá a paleta de cores.
- **Terminais & Apps padrão:** Edite o topo de `~/.config/hypr/hyprland.conf`:
  ```ini
  $terminal = kitty
  $browser = brave
  $fileManager = thunar
  ```

---

## 📄 Licença

Este projeto é distribuído sob a licença [MIT](LICENSE). Desenvolvido com carinho por **Lucas Damasceno**.
