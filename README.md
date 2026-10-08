<div align="center">

# ⚡ ZENITH-SHELL
### Next-Generation Linux Desktop Shell & Standalone Wayland Engine
*Powered by **Hyprland**, **Rust (Engine v2)** & **Luau Scripting***

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00c8ff.svg)](https://hyprland.org)
[![Rust Engine](https://img.shields.io/badge/Engine-Rust_v2-red.svg)](crates/)
[![Luau](https://img.shields.io/badge/Scripting-Luau-blue.svg)](config/zenith/)
[![Memory](https://img.shields.io/badge/Memory-12.9_MB_VmRSS-brightgreen.svg)](#)
[![Reload](https://img.shields.io/badge/Reload-6.8_ms-brightgreen.svg)](#)

**Zenith-Shell** é uma interface e engine de desktop de altíssima performance para Wayland. Construída em Rust com estilização declarativa em Luau, consome menos de 15 MB de RAM, suporta recarga sub-10ms e oferece paridade total de recursos: launcher inteligente, docking interativa, painel dinâmico (dynamic island), lock screen de alta segurança, roteamento PipeWire e telemetria de hardware em tempo real.

</div>

---

## 🌟 Principais Recursos

- ⚡ **Standalone Rust Engine (v2) & Luau:** Sub-10ms hot-reload (`6.8ms`), consumo ínfimo de memória (`~12.9 MB VmRSS`) e zero dependências de runtimes pesados (zero Qt/Electron).
- 🎨 **Sincronização Dinâmica de Cores (Material You):** Integração com **Matugen** e Stylix gerando paletas tonais em tempo real.
- 🔍 **Launcher Inteligente:** Busca rápida de aplicativos XDG com fuzzy search, atalhos de teclado, cursor interativo e botão de limpeza (`search:clear`).
- 🖥️ **Multi-Monitor Cloning & Workspace Filtering:** Renderização independente e double-buffering damage tracking por monitor, filtrando workspaces automaticamente via `Zenith.current_output()`.
- 🔒 **Screen Locker Nativo (`LockScreen.luau`):** Overlay em tela cheia com proteção exclusiva de teclado (`Layer::Overlay`), relógio digital, previsão do tempo, avatar do usuário e ações de energia (`zenith lock`).
- 🎛️ **Audio Sink Switcher:** Seletor interativo de saída de áudio PipeWire via `wpctl status` integrado no `AudioPopup.luau`.
- 🌦️ **Weather & Recorder Telemetry:** Previsão do tempo assíncrona em cache e indicador de gravação de tela (`wf-recorder`) com ferramenta de recorte (`grim` + `slurp`).
- 🪟 **Interactive Dock & Dynamic Island:** Dock flutuante inferior com rastreamento de janelas e Dynamic Island no topo animada com física de molas (Springs).
- 🔔 **Serviço de Notificações Integrado:** Daemon nativo D-Bus (`org.freedesktop.Notifications`) com central de notificações expansível.

---

## 📦 Arquitetura do Projeto

```text
Zenith-Shell/
├── crates/                     # Rust Engine v2 (Standalone Shell)
│   ├── zenith-core/            # Tipos compartilhados e física de molas (Springs)
│   ├── zenith-services/        # Telemetria, Hyprland, Audio sinks, Bluetooth, Weather, Recorder
│   ├── zenith-layout/          # Flexbox Taffy 0.14 e medição tipográfica
│   ├── zenith-runtime/         # VM Luau (mlua 0.12) e bindings de ecossistema
│   ├── zenith-wayland/         # SCTK 0.19, wlr-layer-shell multi-monitor e renderizador 2-pass
│   └── zenith-cli/             # Daemon principal, watcher e controle IPC via socket
├── config/
│   ├── zenith/                 # Configuração declarativa Luau (bar.luau, widgets, overlays)
│   ├── hypr/                   # Configurações Hyprland
│   └── quickshell/             # Configuração legada QML (opcional)
├── flake.nix                   # Flake NixOS com pacotes e devShell
└── nix/home-manager.nix        # Módulo declarativo para Home Manager
```

---

## 💻 CLI & Controle IPC (`zenith`)

```bash
zenith daemon [path]    # Inicia o daemon do shell (default: config/zenith/bar.luau)
zenith reload           # Recarrega a configuração Luau em sub-10ms
zenith toggle <popup>   # Alterna overlay (ex: Launcher, AudioPopup, CalendarPopup)
zenith open <popup>     # Abre overlay especificado
zenith close            # Fecha o overlay ativo
zenith lock             # Bloqueia a sessão com o Lock Screen nativo
zenith inspect          # Exibe telemetria em tempo real (VmRSS, heap, popups)
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
