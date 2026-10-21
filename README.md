<div align="center">

# ⚡ ZENITH-SHELL
### Next-Generation Linux Desktop Shell & Standalone Wayland Engine
*Powered by **Hyprland**, **Rust (Engine v3)** & **Luau Scripting***

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00c8ff.svg)](https://hyprland.org)
[![Rust Engine](https://img.shields.io/badge/Engine-Rust_v3-red.svg)](crates/)
[![Luau](https://img.shields.io/badge/Scripting-Luau-blue.svg)](config/zenith/)
[![Memory](https://img.shields.io/badge/Memory-12.9_MB_VmRSS-brightgreen.svg)](#)
[![Reload](https://img.shields.io/badge/Reload-6.8_ms-brightgreen.svg)](#)

**Zenith-Shell** é uma interface e engine de desktop de altíssima performance para Wayland. Construída em Rust com estilização e lógica declarativa em Luau, consome menos de 15 MB de RAM, suporta recarga sub-10ms e oferece paridade total e independente: launcher inteligente, docking interativa com magnificação e auto-hide, painel dinâmico (dynamic island), lock screen de alta segurança, aceleração gráfica GLES 3.0 com blur Kawase, roteamento PipeWire e telemetria de hardware em tempo real sem qualquer dependência de runtimes pesados (zero Qt/Electron).

</div>

---

## 🌟 Principais Recursos

- ⚡ **Standalone Rust Engine (v3) & Luau Reativo:** Sub-10ms hot-reload (`6.8ms`), consumo ínfimo de memória (`~12.9 MB VmRSS`), sistema de sinais reativos (`Zenith.signal`, `Zenith.computed`, `Zenith.effect`) e persistência atômica chave-valor (`Zenith.Storage`).
- 🚀 **Pipeline Gráfico Dual (GLES 3.0 & SHM):** Renderizador acelerado por hardware via Wayland EGL + OpenGL ES 3.0 com shader Dual-Pass Kawase Blur, Texture Atlas para `cosmic-text` e damage tracking por monitor, com fallback eficiente em memória compartilhada via `tiny-skia`.
- 🎨 **Sincronização Dinâmica de Cores (Material You):** Integração com **Matugen** e Stylix gerando paletas tonais em tempo real com recarga automática via `theme_watcher`.
- 🔍 **Launcher Inteligente & Editor Interativo:** Busca rápida de aplicativos XDG com fuzzy search, navegação por teclado e editor de texto multilinhas integrado em `zenith-layout` com cursor, seleção e histórico undo/redo.
- 🖥️ **Multi-Monitor Cloning & Foreign Toplevel:** Renderização independente por monitor filtrando workspaces via `Zenith.current_output()`, com tracking global de janelas via protocolo `zwlr_foreign_toplevel_manager_v1`.
- 🔒 **Screen Locker Nativo (`LockScreen.luau`):** Overlay em tela cheia com proteção exclusiva de teclado (`Layer::Overlay`), relógio digital, previsão do tempo, avatar do usuário e ações de energia (`zenith lock`).
- 🎛️ **Audio Sink Switcher & Cliphist:** Seletor interativo de saída de áudio PipeWire via `wpctl status` integrado no `AudioPopup.luau` e histórico de clipboard com preview rápido.
- 🌦️ **Weather, CAVA & Recorder Telemetry:** Previsão do tempo assíncrona em cache, analisador de espectro de áudio CAVA e indicador de gravação de tela (`wf-recorder`) com ferramenta de recorte (`grim` + `slurp`).
- 🪟 **Interactive Dock com Magnificação & Dynamic Island:** Dock flutuante inferior com física de magnificação parabólica/gaussiana, detecção de colisão com janelas, auto-hide dinâmico e Dynamic Island expansível no topo animada com física de molas (Springs).
- 🔔 **Serviço de Notificações Integrado:** Daemon nativo D-Bus (`org.freedesktop.Notifications`) com central de notificações expansível.

---

## 📦 Arquitetura do Projeto

```text
Zenith-Shell/
├── crates/                     # Rust Engine Base v3 (Standalone Shell)
│   ├── zenith-core/            # Tipos compartilhados, física de molas (Springs) e modelo de magnificação
│   ├── zenith-services/        # Telemetria, Hyprland IPC, Audio PipeWire, Bluetooth, Weather, Recorder, CAVA, Cliphist
│   ├── zenith-layout/          # Flexbox Taffy 0.14, medição tipográfica cosmic-text e editor de texto
│   ├── zenith-runtime/         # VM Luau (mlua 0.12), sinais reativos, motor de armazenamento em disco e worker threads
│   ├── zenith-wayland/         # SCTK 0.19, wlr-layer-shell, renderizador dual (GLES 3.0 hardware blur / SHM tiny-skia), foreign toplevel e IME
│   └── zenith-cli/             # Daemon principal, watcher inotify, CLI avançada e controle IPC via socket UNIX
├── config/
│   ├── zenith/                 # Configuração declarativa Luau modular
│   │   ├── bar/                # Módulos e clusters da barra superior (left, center, right, island, pill)
│   │   ├── dock/               # Dock interativa (magnificação, colisão, auto-hide, running apps, menu de contexto)
│   │   ├── canvas/             # Desktop canvas e widgets sobre o wallpaper
│   │   ├── island/             # Dynamic island com notificações e status de mídia
│   │   ├── overlays/           # 22 overlays completos (Launcher, ControlCenter, AudioPopup, LockScreen, etc.)
│   │   ├── widgets/            # Catálogo modular de widgets (desktop, media, shared, system, tools)
│   │   ├── core/               # Popup manager, serviços Luau, motor de temas e componentes UI
│   │   ├── config.json         # Estado persistente de configurações da shell
│   │   └── zenith.d.luau       # Definições estáticas de tipos para Luau LSP
│   └── hypr/                   # Configurações do compositor Hyprland e scripts de integração
├── flake.nix                   # Flake NixOS com pacotes e devShell reproduzível
└── nix/home-manager.nix        # Módulo declarativo para Home Manager
```

---

## 💻 CLI & Controle IPC (`zenith`)

```bash
zenith daemon [path] [--inspect]  # Inicia o daemon do shell (default: config/zenith/bar.luau)
zenith reload                     # Recarrega a configuração Luau em sub-10ms
zenith toggle <popup_id>          # Alterna overlay (ex: Launcher, AudioPopup, CalendarPopup)
zenith open <popup_id>            # Abre overlay especificado
zenith close                      # Fecha o overlay ativo
zenith lock                       # Bloqueia a sessão com o Lock Screen nativo
zenith inspect                    # Exibe telemetria em tempo real (VmRSS, heap, popups)
zenith inspect:toggle             # Alterna bounding boxes visuais na tela para debug
zenith settings get <key>         # Obtém valor de configuração via IPC
zenith settings set <key> <val>   # Altera configuração e persiste atomicamente em disco
zenith settings list              # Lista todas as configurações como JSON
zenith settings sync              # Força flush e persistência de configurações no config.json
zenith settings reload            # Recarrega configurações do config.json no estado em tempo real
zenith eval <code>                # Avalia expressão Luau arbitrária no daemon
zenith repl                       # Inicia sessão interativa Luau REPL conectada ao daemon
```

---

## 🚀 Instalação

### Opção 1: Instalador Universal (Arch, Fedora, Ubuntu, Debian)

```bash
git clone https://github.com/Lucas-Damasceno-dev/Zenith-Shell.git
cd Zenith-Shell
./install.sh
```
*O instalador detectará seu gerenciador de pacotes (`pacman`, `dnf`, `apt`), instalará as dependências e configurará os arquivos em `~/.config/hypr` e `~/.config/zenith`.*

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
