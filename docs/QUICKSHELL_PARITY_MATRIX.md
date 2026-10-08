# Quickshell vs Zenith-Shell Parity Matrix

This document maps all features from the existing Quickshell configuration (`/etc/nixos/home/lucas/modules/desktop/quickshell`) to Zenith-Shell components, tracking porting progress and implementation plans.

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
| **Workspaces IPC** | Hyprland IPC in QML | ⏳ **In Progress** (`zenith-services/hyprland.rs`) | **Milestone 5** |
| **Window Title** | Active window QML property | ⏳ **In Progress** (`hyprland.rs activewindow`) | **Milestone 5** |
| **Audio Popup** | `overlays/AudioPopup.qml` | ⏳ **Planned** (`overlays/AudioPopup.luau`) | **Milestone 6** |
| **Network Popup** | `overlays/NetworkPopup.qml` | ⏳ **Planned** (`overlays/NetworkPopup.luau`) | **Milestone 6** |
| **Calendar Popup** | `overlays/CalendarPopup.qml` | ⏳ **Planned** (`overlays/CalendarPopup.luau`) | **Milestone 6** |
| **Power Menu** | `modules/dashboard/PowerMenu.qml` | ⏳ **Planned** (`overlays/PowerMenu.luau`) | **Milestone 6** |
| **Desktop Dock** | `modules/dock/Dock.qml` | ⏳ **Planned** (`modules/dock/dock.luau`) | **Milestone 8** |
| **MPRIS2 Media Player** | `services/MprisService.qml` | ⏳ **Planned** (`zenith-services/mpris.rs`) | **Milestone 8** |
| **Notification Center** | `modules/notifications/` | ⏳ **Planned** (`zenith-services/notifications.rs`) | **Milestone 8** |
| **OSD HUD** | `overlays/OSD.qml` | ⏳ **Planned** (`overlays/osd.luau`) | **Milestone 8** |
| **Desktop Canvas** | `modules/canvas/DesktopCanvas.qml` | ⏳ **Planned** (Background layer shell window) | **Milestone 8** |
| **NixOS Flake Integration**| `default.nix` in Home Manager | ⏳ **Planned** (Native flake build + systemd unit) | **Milestone 9** |

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
  - Battery: Direct reads on `/sys/class/power_supply/BAT*`.
  - Eliminates subshell forks and bash process spawning during 1-second telemetry ticks.
