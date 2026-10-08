# Zenith Desktop Shell (Engine v2) — Developer Workflow
set shell := ["bash", "-c"]

# Default recipe: display available commands
default:
    @just --list

# Start the Zenith shell daemon
run config="config/zenith/bar.luau":
    cargo run -p zenith-cli -- daemon {{config}}

# Start the daemon with verbose debug tracing
dev config="config/zenith/bar.luau":
    RUST_LOG=zenith=debug,zenith_core=debug,zenith_wayland=debug cargo run -p zenith-cli -- daemon {{config}}

# Trigger sub-10ms instant hot-reload via UNIX socket
reload:
    cargo run -q -p zenith-cli -- reload

# Toggle an overlay widget (Launcher, Dock, DynamicIsland, MediaPopup, NotificationCenter, AudioPopup, etc.)
toggle popup="Launcher":
    cargo run -q -p zenith-cli -- toggle {{popup}}

# Toggle Dock
dock:
    cargo run -q -p zenith-cli -- toggle Dock

# Toggle Dynamic Island
island:
    cargo run -q -p zenith-cli -- toggle DynamicIsland

# Toggle Desktop Canvas
canvas:
    cargo run -q -p zenith-cli -- toggle DesktopCanvas

# Open an overlay widget
open popup="Launcher":
    cargo run -q -p zenith-cli -- open {{popup}}

# Dismiss current overlay
close:
    cargo run -q -p zenith-cli -- close

# Inspect live daemon metrics (VmRSS, Luau Heap, Window state)
inspect:
    cargo run -q -p zenith-cli -- inspect

# Check cargo workspace without building binaries
check:
    cargo check --workspace

# Run all workspace unit tests
test:
    cargo test --workspace

# Build optimized release binary
build:
    cargo build --release -p zenith-cli

# Package and build via Nix Flake
nix-build:
    nix build .#zenith-shell

# Format codebase
fmt:
    cargo fmt --all
