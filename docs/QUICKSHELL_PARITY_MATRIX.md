# Quickshell vs Zenith-Shell Parity Matrix

This document maps all features from the existing Quickshell configuration (`/etc/nixos/home/lucas/modules/desktop/quickshell`) to Zenith-Shell components, tracking porting progress and implementation plans.

> 📖 **Guia Operacional para IA:** Para instruções passo a passo de desenvolvimento e SOP de migração entre sessões, consulte o [QUICKSHELL_MIGRATION_PLAYBOOK.md](QUICKSHELL_MIGRATION_PLAYBOOK.md).

---

## 📊 Overview Matrix

| Component Area | Quickshell (Qt6/QML) Path | Zenith-Shell (Rust/Luau) Status | Target Milestone |
| :--- | :--- | :--- | :--- |
| **Top Bar** | `modules/bar/Bar.qml` | ✅ **Implemented** (`config/zenith/bar.luau`) | Milestone 1-4 |
| **Material You Theme** | `core/ColorScheme.qml` | ✅ **Implemented** (`Zenith.Theme()`, Matugen JSON) | Milestone 3 |
| **Hardware Telemetry** | `services/SystemMetricsService.qml` | ✅ **Implemented** (CPU, RAM, Battery, Clock) | Milestone 3 |
| **Audio Service** | `services/AudioService.qml` | ✅ **Implemented** (Native `wpctl` polling) | Milestone 3 |
| **Network Service** | `services/NetworkService.qml` | ✅ **Implemented** (Native `nmcli` polling) | Milestone 3 |
| **Modular UI Kit** | `modules/bar/` widgets | ✅ **Implemented** (`config/zenith/lib/widgets/*`) | Milestone 4 |
| **Pointer Clicks** | QML `MouseArea` | ✅ **Implemented** (Wayland seat hit-testing) | Milestone 2 |
| **Sub-10ms Reload** | `just qs-restart` (~1.5s) | ✅ **Implemented** (File watcher notify: 6.8ms) | Milestone 1 |
| **Workspaces IPC** | Hyprland IPC in QML | ✅ **Implemented** (`zenith-services/hyprland.rs`) | **Milestone 5** |
| **Window Title** | Active window QML property | ✅ **Implemented** (`hyprland.rs activewindow`) | **Milestone 5** |
| **Audio Popup** | `overlays/AudioPopup.qml` | ✅ **Implemented** (`overlays/AudioPopup.luau`) | **Milestone 6** |
| **Network Popup** | `overlays/NetworkPopup.qml` | ✅ **Implemented** (`overlays/NetworkPopup.luau`) | **Milestone 6** |
| **Calendar Popup** | `overlays/CalendarPopup.qml` | ✅ **Implemented** (`overlays/CalendarPopup.luau`) | **Milestone 6** |
| **Power Menu** | `modules/dashboard/PowerMenu.qml` | ✅ **Implemented** (`overlays/PowerMenu.luau`) | **Milestone 6** |
| **Drop Shadows & Blur** | QML RectangularGlow & Blur | ✅ **Implemented** (Tiny-Skia shadows + Hyprland blur) | **Milestone 7** |
| **Spring Animations** | QML NumberAnimation | ✅ **Implemented** (`zenith-core::SpringAnimation`) | **Milestone 7** |
| **App Launcher** | `modules/launcher/` | ✅ **Implemented** (`overlays/Launcher.luau` + `launcher.rs`) | **Milestone 8** |
| **MPRIS2 Media Player** | `services/MprisService.qml` | ✅ **Implemented** (`zenith-services/mpris.rs` + `MediaPopup.luau`) | **Milestone 8** |
| **Notification Center** | `modules/notifications/` | ✅ **Implemented** (`zenith-services/notifications.rs` + `NotificationCenter.luau`) | **Milestone 8** |
| **OSD HUD** | `overlays/OSD.qml` | ✅ **Implemented** (`overlays/OSD.luau`) | **Milestone 8** |
| **NixOS Flake Integration**| `default.nix` in Home Manager | ✅ **Implemented** (`flake.nix` + `home-manager.nix`) | **Milestone 9** |
| **Interactive Dock** | `modules/dock/Dock.qml` | ✅ **Implemented** (`config/zenith/dock.luau` + `overlays/Dock.luau`) | **Milestone 10** |
| **Dynamic Island HUD** | `modules/island/DynamicIsland.qml` | ✅ **Implemented** (`config/zenith/island.luau` + `overlays/DynamicIsland.luau`) | **Milestone 10** |
| **Desktop Canvas** | `modules/canvas/DesktopCanvas.qml` | ✅ **Implemented** (`config/zenith/canvas.luau` + `overlays/DesktopCanvas.luau`) | **Milestone 10** |
| **Bluetooth Popup** | `overlays/BluetoothPopup.qml` | ✅ **Implemented** (`overlays/BluetoothPopup.luau` + `bluetooth.rs`) | **Milestone 11** |
| **Audio Sink Switcher** | Device switcher in AudioPopup | ✅ **Implemented** (`audio.rs` + `overlays/AudioPopup.luau`) | **Milestone 11** |
| **Weather Telemetry** | Weather in DesktopCanvas | ✅ **Implemented** (`weather.rs` + `DesktopCanvas.luau`) | **Milestone 11** |
| **Screen Recorder & Snipping** | External scripts (wf-recorder) | ✅ **Implemented** (`recorder.rs` + `bar.luau`) | **Milestone 11** |
| **Lock Screen Overlay** | `hyprlock` / lock session | ✅ **Implemented** (`LockScreen.luau` + `zenith lock`) | **Milestone 11** |
| **Multi-Output Cloning** | Quickshell Multi-Screen Bar | ✅ **Implemented** (`current_output` + `workspaces.luau`) | **Milestone 11** |
| **Generic Text Input** | QML `TextField` / `TextInput` | ✅ **Implemented** (`Zenith.TextInput`, Wayland seat focus, utf8) | **Milestone 12** |
| **Raster & SVG Blitting** | QML `Image` (raster & SVG) | ✅ **Implemented** (`Zenith.Image`, tiny-skia blit, resvg + png) | **Milestone 12** |
| **Scrollable Viewports** | QML `ScrollView` / `Flickable` | ✅ **Implemented** (`overflow = "scroll"`, pointer axis offset) | **Milestone 12** |
| **Dynamic Layer-Shell** | QML Window anchor/margins | ✅ **Implemented** (`Zenith.Window`, dynamic Anchor/Margins/Layer) | **Milestone 12** |
| **Brightness Telemetry** | `services/BrightnessService.qml` | ✅ **Implemented** (`brightness.rs`, `/sys/class/backlight`) | **Milestone 12** |
| **Disk Storage Service** | `services/DiskAnalyzerService.qml` | ✅ **Implemented** (`disk.rs`, libc `statvfs`) | **Milestone 12** |
| **Power Profile Switching** | Power profiles daemon in QML | ✅ **Implemented** (`power.rs`, `powerprofilesctl`) | **Milestone 12** |
| **Settings Hub & Center** | `modules/settings/` | ✅ **Implemented** (`overlays/Settings.luau` + `settings_store.luau`) | **Milestone 13** |
| **Modular Bar Architecture**| `Bar.qml` + `RightBarModules.qml` | ✅ **Implemented** (`config/zenith/bar/` + `widgets/*`) | **Milestone 13** |
| **UI Kit & Design System** | Reusable QML Controls | ✅ **Implemented** (`config/zenith/ui_kit.luau` + `core/ui/*`) | **Milestone 13** |
| **Control Center**          | `overlays/ControlCenterPopup.qml` | ✅ **Implemented** (`overlays/ControlCenter.luau`) | **Milestone 15 (Onda 5.1)** |
| **Clipboard Popup (Cliphist)**| `overlays/ClipboardPopup.qml` | ✅ **Implemented** (`overlays/ClipboardPopup.luau` + `lib/widgets/clipboard.luau`) | **Milestone 14 (Onda 2.1)** |
| **System Monitor Popup**    | `modules/system_monitor/` / `SystemMonitorUtils.js` | ✅ **Implemented** (`overlays/SystemMonitorPopup.luau`) | **Milestone 14 (Onda 2.2)** |
| **USB & Removable Media**   | `modules/usb/` / `UsbService.qml` | ✅ **Implemented** (`overlays/USBPopup.luau` + `lib/widgets/usb.luau`) | **Milestone 14 (Onda 2.3)** |
| **Battery Health & Profiles**| `overlays/BatteryPopup.qml` | ✅ **Implemented** (`overlays/BatteryPopup.luau` + `lib/widgets/battery.luau`) | **Milestone 14 (Onda 2.3)** |
| **Audio & Media Mixer**     | `overlays/AudioPopup.qml` & `MediaPopup.qml` | ✅ **Implemented** (`overlays/AudioPopup.luau` & `MediaPopup.luau`) | **Milestone 14 (Onda 2.4)** |
| **Window Exposé / Switcher**| `overlays/ExposePopup.qml` | ✅ **Implemented** (`overlays/ExposePopup.luau`) | **Milestone 15 (Onda 5.2)** |
| **Scratchpad Drawer**       | `overlays/ScratchpadDrawer.qml` | ✅ **Implemented** (`overlays/ScratchpadDrawer.luau`) | **Milestone 15 (Onda 5.3)** |
| **Screen Draw Annotation**  | `overlays/ScreenDrawOverlay.qml` | ✅ **Implemented** (`overlays/ScreenDrawOverlay.luau`) | **Milestone 15 (Onda 5.4)** |
| **Custom Luau Validation Suite** | QML lint / parity verification | ✅ **Implemented** (`tests/validate_custom_suite.py` - 61/61 files) | **Milestone 15 (100% Parity)** |

---

## 🎯 Direct Component Mapping Reference

### 1. Theming & Design Tokens
- **Quickshell:** `core/DesignTokens.qml`, `core/ColorScheme.qml` parses `~/.cache/quickshell/matugen/colors.json`.
- **Zenith:** `zenith-services` loads the same JSON; exposed to Luau via `Zenith.Theme()`.
- **Colors Available:**
  - `theme.background` (Dark slate base)
  - `theme.surface` (Card and pill backgrounds)
  - `theme.primary` (Accent highlights)
  - `theme.on_surface` (Primary text color)
  - `theme.outline` (Subtle borders)

### 2. Bar Layout Structure
- **Quickshell (`Bar.qml`):**
  - Left: Launcher button (`modules/launcher`), Workspaces (`modules/workspaces`), Active Window Title.
  - Center: Media controller (`MprisWidget`), Clock pill (`ClockWidget`).
  - Right: System metrics (CPU, RAM, Temp), Network pill, Audio pill, Battery pill, Power button.
- **Zenith (`config/zenith/bar.luau`):**
  - Left: `Launcher`, `Workspaces`, Focused app chip.
  - Center: Media status pill, `Clock`.
  - Right: `Hardware` (CPU/RAM), `QuickStatus` (WiFi/Audio/Battery/Power).

### 3. Scripts vs Native Engine Services
- Quickshell executes dozens of external shell scripts in `/etc/nixos/home/lucas/modules/desktop/scripts/`.
- Zenith-Shell replaces fork-exec overhead with native in-process Rust readers:
  - Memory: Direct `/proc/self/statm` + libc `sysinfo`.
  - CPU: Delta tracking on `/proc/stat`.
  - Eliminates subshell forks and bash process spawning during 1-second telemetry ticks.

### 4. Overlays & Specialized Popups
- **Clipboard Popup (`overlays/ClipboardPopup.luau`):** Paridade integral com o histórico cliphist do Quickshell (`cliphist list`, `cliphist decode`, preview de imagem/texto, filtro por categoria, pesquisa em tempo real, wipe de histórico e atalhos de seleção rápida).
- **System Monitor Popup (`overlays/SystemMonitorPopup.luau`):** Telemetria em tempo real (CPU, RAM, Swap, Root/Home Disk), tabela dinâmica de processos ordenados por CPU/RAM com ação de término (`kill -TERM`), visualização de serviços systemd (`pipewire`, etc.) e integração com utilitários de terminal (`btop`, `htop`).
- **USB & Removable Media Popup (`overlays/USBPopup.luau`):** Detecção de dispositivos de bloco e pendrives via `udisks2`/`lsblk`, botões de montagem/desmontagem rápida e ejetar com segurança.
- **Battery Health Popup (`overlays/BatteryPopup.luau`):** Estimativa de tempo restante, contagem de ciclos de carga, saúde percentual da bateria e seletor de perfis de energia (`power-profiles-daemon`).
- **Audio & Media Mixer (`overlays/AudioPopup.luau`, `overlays/MediaPopup.luau`):** Controle de volume por aplicação/stream PipeWire, troca de sink/source de áudio e controle de reprodução MPRIS com visualização de capa e scrubber.
- **Control Center (`overlays/ControlCenter.luau`):** Central unificada de toggles rápidos, sliders de áudio/brilho, mini-player MPRIS e perfis de energia.
- **Window Exposé / Overview (`overlays/ExposePopup.luau`):** Visão geral Mission Control de janelas ativas, filtros por workspace e atalhos rápidos de fechamento/foco.
- **Scratchpad Drawer (`overlays/ScratchpadDrawer.luau`):** Gerenciador visual dedicado de janelas em workspaces especiais do Hyprland.
- **Screen Draw & Annotation (`overlays/ScreenDrawOverlay.luau`):** Barra flutuante de ferramentas de marcação vetorial livre e anotação em tempo real.

### 5. Arquitetura Modular Luau & Paridade Sintática
- **Validador Oficial:** `tests/test_luau_syntax.py`
- **Cobertura:** 100+ arquivos Luau modulares em `config/zenith/` (100% aprovados com 0 erros de sintaxe e delimitadores perfeitamente balanceados).
- **Inventário Auditado:**
  - Overlays em `config/zenith/overlays/` (`AudioPopup`, `BatteryPopup`, `ControlCenter`, `Dock`, `Launcher`, `LockScreen`, `OSD`, `PowerMenu`, `Settings`, etc.)
  - Widgets modulares categorizados em `config/zenith/widgets/` (`desktop/`, `media/`, `shared/`, `system/`, `tools/`)
  - Módulos de subsistemas dedicados: `config/zenith/bar/`, `dock/`, `canvas/`, `launcher/`, `osd/`, `settings/`
  - Design tokens, serviços e UI Kit em `config/zenith/core/` e `ui_kit.luau`
  - Ponto de entrada e contratos de tipos: `bar.luau`, `dock.luau`, `canvas.luau`, `island.luau`, `zenith.d.luau`
