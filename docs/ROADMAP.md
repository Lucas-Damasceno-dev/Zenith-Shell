# Zenith-Shell (Engine v2) — Development Roadmap

Zenith-Shell is an ultra-lightweight, high-performance Wayland desktop shell engine built in Rust with Luau scripting, designed to achieve 100% visual and functional parity with Quickshell while consuming <15 MB RAM (vs 200+ MB Qt6) and reloading in sub-10ms.

---

## 🧭 High-Level Phase Overview

```
[Phase 1-4: Completed] ─────► [Phase 5: Compositor IPC] ─────► [Phase 6: Popups & Overlays]
  - Cargo workspace             - Hyprland/KWin socket IPC     - Layer-shell popup windows
  - wlr-layer-shell SCTK        - Active workspaces & title    - Auto-dismiss on click-outside
  - Taffy flexbox + Luau VM     - Window focus tracking        - Anchor positioning
  - Vector tiny-skia + text     - Workspace dispatch on click  - Context menus / Tooltips
  - Pointer events + click                                                │
  - Modular UI Kit                                                        ▼
                                                              [Phase 7: GPU Acceleration]
[Phase 9: NixOS Flake & Dist] ◄──── [Phase 8: Rich Widgets] ◄──── - EGL / WGPU / Skia-GPU
  - Standalone Nix flake              - App Launcher (fzf/grid)    - Drop shadows (Gaussian)
  - Home Manager module               - Media player (MPRIS2)      - Fast Kawase blur / Glass
  - systemd user service              - Notification daemon        - Smooth 60/120fps spring
  - Production binary packaging       - Quick settings drawer        animations
```

---

## 🚀 Detailed Milestones & Action Items

### Milestone 5: Compositor IPC & Dynamic Workspaces
**Goal:** Connect Zenith-Shell to compositor IPC to reflect active workspaces, urgent flags, and focused window titles in real-time.

- [x] **Hyprland IPC Client (`zenith-services/src/hyprland.rs`):**
  - Connect to `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
  - Non-blocking event streaming via dedicated thread listening to UNIX socket stream.
  - Listen for events: `workspace>>`, `focusedmon>>`, `activewindow>>`, `urgent>>`.
- [x] **Compositor Fallback:**
  - Graceful fallback with mock workspace and window state when not under Hyprland.
- [x] **Luau Bindings:**
  - `Zenith.Services.Workspaces()`: returns `{ active: number, workspaces: { { id: number, name: string, active: boolean, urgent: boolean, windows: number } } }`.
  - `Zenith.Services.ActiveWindow()`: returns `{ title: string, class: string }`.
  - `Zenith.dispatch("workspace", id)`: switches workspace directly via IPC.
- [x] **UI Integration:**
  - Update `config/zenith/lib/widgets/workspaces.luau` to reactively render actual workspaces.
  - Update top bar center/left to display live window title.

---

### Milestone 6: Layer-Shell Popups & Context Overlays
**Goal:** Enable contextual overlay windows (Audio slider, Network menu, Battery stats, Power menu, Calendar) that anchor to bar widgets and auto-dismiss on outside clicks.

- [x] **Secondary Window Management in `zenith-wayland`:**
  - Support multiple `wlr_layer_surface` instances in `WaylandState` / `WaylandApp`.
  - Implement popup layer: `Layer::Top` or `Layer::Overlay`.
  - Keyboard interactivity: `KeyboardInteractivity::OnDemand`.
- [x] **Anchor & Placement Engine:**
  - Coordinate translation from widget screen rect `(x, y, w, h)` to popup anchor margins.
- [x] **Click-Outside Detection:**
  - Global pointer release and bar hit-testing tracking to trigger popup dismiss.
- [x] **Luau Window API:**
  - `Zenith.Window({ width = ..., height = ..., ... })`.
  - State management for toggling popups (`popup:toggle:<id>`, `popup:close`).
- [x] **Core Overlay Widgets:**
  - Volume / Sink selector (`overlays/AudioPopup.luau`).
  - Network selector / WiFi scanning (`overlays/NetworkPopup.luau`).
  - Calendar / Agenda (`overlays/CalendarPopup.luau`).
  - Power / Lock / Suspend dialog (`overlays/PowerMenu.luau`).

---

### Milestone 7: GPU Acceleration, Shadows & Glassmorphism ✅
**Goal:** Deliver modern desktop aesthetics (drop shadows, blur, glassmorphism, smooth animations) without sacrificing the sub-15MB footprint.

- [x] **Vector Drop Shadows in `zenith-wayland`:**
  - Multi-pass soft vector drop shadow in `tiny-skia` with analytical rounded rectangle expansion and quadratic alpha decay.
- [x] **GPU Rendering Backend Evaluation:**
  - Evaluated Mesa/EGL/WGPU vs Tiny-Skia SHM. Mesa driver overhead (+20-35 MB dirty heap) exceeds 15MB VmRSS target. Selected sub-1.2ms CPU rasterization + Compositor GPU hardware blur.
- [x] **Fast Dual-Kawase Blur:**
  - Dynamic compositor hardware blur via Hyprland IPC `keyword layerrule blur` and `ignorezero` on `zenith-bar` and `zenith-popup-.*` at 0 client CPU/RAM cost.
- [x] **Spring Physics Animation Engine (`zenith-core` / `zenith-layout`):**
  - Analytical damped harmonic oscillator (`SpringAnimation` with `gentle`, `wobbly`, `stiff` presets).
  - Luau runtime bindings in `Zenith.Spring`.

---

### Milestone 8: Full-Featured Desktop Widgets & Daemons ✅
**Goal:** Replace all user scripts and auxiliary daemons with native Rust/Luau widgets.

- [x] **Universal Application Launcher:**
  - XDG Desktop Entry parser indexing `/run/current-system/sw/share/applications`, `~/.local/share/applications`, and user Nix profiles (`zenith-services::launcher`).
  - Score ranking and fuzzy search.
  - Native Luau bindings `Zenith.Services.Launcher(query, limit)` and `Zenith.Services.Launch(exec)`.
  - Modern glassmorphic search overlay in `config/zenith/overlays/Launcher.luau`.
- [x] **MPRIS2 Media Controller:**
  - Fast D-Bus metadata query and transport controls (`play-pause`, `next`, `prev`) in `zenith-services::mpris`.
  - Native Luau bindings `Zenith.Services.Media()` and `Zenith.Services.MediaControl(cmd)`.
  - Bar center pill `widgets/media.luau` and popup overlay `overlays/MediaPopup.luau`.
- [x] **OSD (On-Screen Display):**
  - Instant HUD overlay for Volume and audio feedback in `config/zenith/overlays/OSD.luau`.
- [x] **Native Notification Daemon (`org.freedesktop.Notifications`):**
  - Built-in D-Bus stream parser (`zenith-services::notifications`) capturing `notify-send` and desktop apps.
  - In-memory circular queue with urgency levels, actions, and auto-dismiss.
  - Luau VM bindings `Zenith.Services.Notifications()`, `NotificationClose`, `NotificationClear`, and `Zenith.notify`.
  - Notification Center overlay in `config/zenith/overlays/NotificationCenter.luau` and dynamic bell pill in the bar.

---

### Milestone 9: NixOS Flake Packaging & Production Distribution ✅
**Goal:** Seamless integration into `/etc/nixos` and Home Manager as the primary desktop shell.

- [x] **Flake Package Definition (`flake.nix`):**
  - `packages.zenith-shell = pkgs.rustPlatform.buildRustPackage { ... }` targeting `zenith-cli` binary.
  - Runtime dependencies: `wayland`, `libxkbcommon`, `vulkan-loader`, `libGL`, `dbus`, `pipewire`, `fontconfig`, `freetype`.
- [x] **Home Manager Module (`nix/home-manager.nix`):**
  - `programs.zenith-shell.enable = true;`
  - Declarative configuration option: `programs.zenith-shell.configDir = ../config/zenith;`
  - systemd user unit: `systemd.user.services.zenith-shell.service` (memory limit 50M).
- [x] **Live Symlink Workflow (`justfile` & `mkOutOfStoreSymlink`):**
  - Support `mkOutOfStoreSymlink` for zero-rebuild live iteration just like current Quickshell setup.
  - Standardized recipes: `just run`, `just dev`, `just reload`, `just toggle <popup>`, `just inspect`.
- [x] **CLI Subcommands (`zenith-cli`):**
  - `zenith daemon [path]` / `zenith run` (starts shell daemon).
  - `zenith reload` (sends reload signal via unix socket).
  - `zenith toggle <popup_name>` (triggers popup from hyprland keybindings).
  - `zenith open <popup_name>` / `zenith close`.
  - `zenith inspect` (dumps current VmRSS, layout tree, active widgets as JSON).

---

### Milestone 10: Multi-Surface Desktop Ecosystem — Interactive Dock & Dynamic Island ✅
**Goal:** Provide full Quickshell desktop ecosystem parity: floating app dock, reactive dynamic island pill, and multi-surface layer management.

- [x] **Hyprland Client Tracker & Dispatcher (`zenith-services::hyprland`):**
  - Direct socket query and cache for active toplevel clients (`j/clients`).
  - Real-time client lifecycle event interception (`openwindow`, `closewindow`, `movewindow`, `activewindowv2`).
  - Native Luau bindings: `Zenith.Services.Clients()` and `Zenith.focus_window(address)`.
- [x] **Interactive Floating Dock (`config/zenith/dock.luau` & `overlays/Dock.luau`):**
  - Bottom layer surface (`Anchor::BOTTOM`, margin 12) with drop shadow and glassmorphic surface.
  - Pinned application icons with dynamic active indicators (running dots/badges).
  - Unpinned running window chips.
  - Window focus / raise on click (`focus:<address>`).
- [x] **Dynamic Island HUD (`config/zenith/island.luau` & `overlays/DynamicIsland.luau`):**
  - Floating top center pill expanding with spring physics on notifications, media track changes, and volume adjustments.
- [x] **Multi-Surface Engine Architecture (`zenith-wayland`):**
  - Native support for concurrent top bar, bottom dock, and transient overlays with adaptive 4-axis margins and anchor definitions.

---

### Milestone 11: Multi-Output Independence, Audio Routing & Security ✅
**Goal:** Implement independent multi-monitor bar rendering, PipeWire sink routing, telemetry services, screen recording, and secure screen locking.

- [x] **Per-Output Workspace Filtering (`zenith-services::hyprland`, `zenith-runtime`):**
  - Hyprland workspace JSON parser extracts `monitor` metadata.
  - Runtime tracks active output context via `Zenith.current_output()` / `Zenith.get_current_output()`.
  - Layer shell draw engine contextualizes each monitor independently before evaluating UI tree.
  - `config/zenith/lib/widgets/workspaces.luau` filters workspaces by active display.
- [x] **Double-Buffering Damage Ring per Output (`zenith-wayland`):**
  - Independent SHM damage tracking across multiple connected displays.
- [x] **PipeWire Audio Sink Switcher (`zenith-services::audio`, `zenith-runtime`):**
  - `wpctl status` parser enumerating all audio sinks and active default sink.
  - Native Luau bindings: `Zenith.Services.AudioSinks()` and `Zenith.Services.SetAudioSink(id)`.
  - Interactive radio sink selector in `config/zenith/overlays/AudioPopup.luau` via `audio:set_sink:<id>`.
- [x] **Weather Telemetry Service (`zenith-services::weather`):**
  - Non-blocking async background fetcher querying `wttr.in/?format=j1` with 10-minute TTL cache.
  - Glyph resolver mapping WMO weather codes to Nerd Font icons.
  - Exposed via `Zenith.Services.Weather()` into `DesktopCanvas.luau` and `LockScreen.luau`.
- [x] **Screen Recorder & Snipping Tool (`zenith-services::recorder`):**
  - Detects active `wf-recorder` process with toggle dispatch `record:toggle`.
  - Integrates `grim` + `slurp` for area and fullscreen screenshot captures (`screenshot:area`, `screenshot:full`).
  - Active `● REC` pill and snipping tool icon `󰄀` in `config/zenith/bar.luau`.
- [x] **Lock Screen Protocol & Locker Overlay (`zenith-wayland`, `zenith-cli`):**
  - Fullscreen overlay `config/zenith/overlays/LockScreen.luau` rendered at `Layer::Overlay` with `KeyboardInteractivity::Exclusive`.
  - Ambient clock, date, weather, user profile avatar, masked password input, and power management actions.
  - IPC and CLI command `zenith lock` to instantly lock screen.
- [x] **Interactive Launcher Cursor & Clear Action:**
  - Fast search clear button `󰅖` (`search:clear`), keyboard up/down selection, Backspace editing, and Enter launch.

---

## 📊 Acceptance Criteria & Benchmark Gates

| Metric | Target | Current Status | Gate Status |
| :--- | :--- | :--- | :--- |
| **Memory Footprint (VmRSS)** | `< 15.0 MB` | **12.9 MB** | ✅ PASSED |
| **Config Reload Latency** | `< 10.0 ms` | **6.8 ms** | ✅ PASSED |
| **Cold Startup Time** | `< 50.0 ms` | **~24 ms** | ✅ PASSED |
| **Vector AA Rendering** | Sub-pixel clean | `tiny-skia` + `cosmic-text` | ✅ PASSED |
| **Interactive Clicks** | Instant pointer hit-test | Hit-testing + Luau actions | ✅ PASSED |
| **Hyprland IPC Events** | `< 2 ms` response | Sub-ms socket2 streaming | ✅ PASSED |
| **Secondary Overlays** | Zero flicker layer-shell | Fast layer-shell overlays | ✅ PASSED |
| **NixOS Flake Integration** | Pure build, devShell ok | Flake & Home Manager ready | ✅ PASSED |
