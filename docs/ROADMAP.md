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

- [ ] **Hyprland IPC Client (`zenith-services/src/hyprland.rs`):**
  - Connect to `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
  - Non-blocking event streaming via `calloop` unix stream source or dedicated async task.
  - Listen for events: `workspace>>`, `focusedmon>>`, `activewindow>>`, `urgent>>`.
- [ ] **KWin / Generic Wayland Fallback (`zenith-services/src/kwin.rs` or `ext-workspace`):**
  - Fallback DBus connection (`org.kde.KWin`) or `ext_workspace_v1` protocol where supported.
- [ ] **Luau Bindings:**
  - `Zenith.Services.Workspaces()`: returns `{ active: number, workspaces: { { id: number, name: string, active: boolean, urgent: boolean, windows: number } } }`.
  - `Zenith.Services.ActiveWindow()`: returns `{ title: string, class: string }`.
  - `Zenith.dispatch("workspace", id)`: switches workspace directly via IPC.
- [ ] **UI Integration:**
  - Update `config/zenith/lib/widgets/workspaces.luau` to reactively render actual workspaces.
  - Update top bar center/left to display live window title.

---

### Milestone 6: Layer-Shell Popups & Context Overlays
**Goal:** Enable contextual overlay windows (Audio slider, Network menu, Battery stats, Power menu, Calendar) that anchor to bar widgets and auto-dismiss on outside clicks.

- [ ] **Secondary Window Management in `zenith-wayland`:**
  - Support multiple `wlr_layer_surface` instances in `WaylandState`.
  - Implement popup layer: `Layer::Top` or `Layer::Overlay`.
  - Keyboard interactivity: `KeyboardInteractivity::OnDemand`.
- [ ] **Anchor & Placement Engine:**
  - Coordinate translation from widget screen rect `(x, y, w, h)` to popup anchor margins.
- [ ] **Click-Outside Detection:**
  - Global pointer release tracking to trigger `popup.dismiss()`.
- [ ] **Luau Window API:**
  - `Zenith.Window({ layer = "overlay", anchor = { top = true, right = true }, exclusive = false, ... })`.
  - State management for toggling popups (`Zenith.toggle_popup("audio")`).
- [ ] **Core Overlay Widgets:**
  - Volume / Sink selector (`overlays/AudioPopup.luau`).
  - Network selector / WiFi scanning (`overlays/NetworkPopup.luau`).
  - Calendar / Agenda (`overlays/CalendarPopup.luau`).
  - Power / Lock / Suspend dialog (`overlays/PowerMenu.luau`).

---

### Milestone 7: GPU Acceleration, Shadows & Glassmorphism
**Goal:** Deliver modern desktop aesthetics (drop shadows, blur, glassmorphism, smooth animations) without sacrificing the sub-15MB footprint.

- [ ] **Vector Drop Shadows in `zenith-wayland`:**
  - Multi-pass blurred bounding box rendering in `tiny-skia` using separable 1D box blur or analytical rounded rectangle drop shadow shaders.
- [ ] **GPU Rendering Backend Evaluation:**
  - Prototype EGL / WGPU / Skia-GPU Wayland surface backend.
  - Compare VmRSS: ensure memory overhead remains < 25 MB under GPU backend.
- [ ] **Fast Dual-Kawase Blur:**
  - Emulate or apply background blur via Wayland compositor protocol (`org_kde_kwin_blur` / `hyprland_surface_blur` / `fractional_scale`).
- [ ] **Spring Physics Animation Engine (`zenith-core` / `zenith-layout`):**
  - Implement damped harmonic oscillator (`SpringAnimation` with stiffness, damping, mass).
  - Drive properties: `opacity`, `transform_x`, `transform_y`, `width`.
  - Frame callback bound to `wl_surface.frame` for 100% tear-free V-Sync matching monitor refresh rate (60Hz / 120Hz / 144Hz).

---

### Milestone 8: Full-Featured Desktop Widgets & Daemons
**Goal:** Replace all user scripts and auxiliary daemons with native Rust/Luau widgets.

- [ ] **Universal Application Launcher:**
  - XDG Desktop Entry parser (`/run/current-system/sw/share/applications`, `~/.local/share/applications`).
  - Fast fuzzy matcher (e.g. `nucleo-matcher` or `skim-matcher`).
  - Grid/list layout with icons loaded via `resvg` / icon theme resolution.
- [ ] **MPRIS2 Media Controller:**
  - Native DBus listener on `org.mpris.MediaPlayer2.*`.
  - Album art fetcher and caching, play/pause/next/prev controls, track timeline slider.
- [ ] **Native Notification Daemon (`org.freedesktop.Notifications`):**
  - Built-in DBus service in `zenith-services`.
  - Toast notification queue with timeouts, action buttons, app icon rendering.
- [ ] **OSD (On-Screen Display):**
  - Transient screen-centered HUD for Volume change, Brightness change, Mic mute toggle.

---

### Milestone 9: NixOS Flake Packaging & Production Distribution
**Goal:** Seamless integration into `/etc/nixos` and Home Manager as the primary desktop shell.

- [ ] **Flake Package Definition (`flake.nix`):**
  - `packages.zenith-shell = pkgs.rustPlatform.buildRustPackage { ... }`.
  - Native dependencies: `wayland`, `wayland-protocols`, `libxkbcommon`, `fontconfig`, `freetype`.
- [ ] **Home Manager Module (`nix/home-manager-module.nix`):**
  - `programs.zenith-shell.enable = true;`
  - Declarative configuration option: `programs.zenith-shell.config = ./config/zenith;`
  - systemd user unit: `systemd.user.services.zenith-shell.service`.
- [ ] **Live Symlink Workflow (`just zenith-reload`):**
  - Support `mkOutOfStoreSymlink` for zero-rebuild live iteration just like current Quickshell setup.
- [ ] **CLI Subcommands (`zenith-cli`):**
  - `zenith run` (starts shell daemon).
  - `zenith reload` (sends reload signal via unix socket).
  - `zenith toggle <popup_name>` (triggers popup from hyprland keybindings).
  - `zenith inspect` (dumps current VmRSS, layout tree, active widgets).

---

## 📊 Acceptance Criteria & Benchmark Gates

| Metric | Target | Current Status | Gate Status |
| :--- | :--- | :--- | :--- |
| **Memory Footprint (VmRSS)** | `< 15.0 MB` | **12.9 MB** | ✅ PASSED |
| **Config Reload Latency** | `< 10.0 ms` | **6.8 ms** | ✅ PASSED |
| **Cold Startup Time** | `< 50.0 ms` | **~24 ms** | ✅ PASSED |
| **Vector AA Rendering** | Sub-pixel clean | `tiny-skia` + `cosmic-text` | ✅ PASSED |
| **Interactive Clicks** | Instant pointer hit-test | Hit-testing + Luau actions | ✅ PASSED |
| **Hyprland IPC Events** | `< 2 ms` response | In roadmap (Phase 5) | ⏳ PENDING |
| **Secondary Overlays** | Zero flicker layer-shell | In roadmap (Phase 6) | ⏳ PENDING |
| **NixOS Flake Integration** | Pure build, devShell ok | Flake devShell active | ⏳ PENDING |
