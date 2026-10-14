# Zenith Desktop Shell (Engine v2) — Developer Workflow
set shell := ["bash", "-c"]
cargo_bin := `if pkg-config --exists wayland-client >/dev/null 2>&1; then echo "cargo"; else echo "nix develop --command cargo"; fi`

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
    {{cargo_bin}} check --workspace

# Run all workspace unit tests
test:
    {{cargo_bin}} test --workspace

# Run IPC socket integration tests
test-ipc:
    {{cargo_bin}} test -p zenith-tests --test ipc_hot_reload -- --nocapture

# Benchmark Luau hot-reload sub-10ms latency
bench-reload:
    {{cargo_bin}} test -p zenith-tests --test bench_hot_reload -- --nocapture

# Run VmRSS memory leak and stability diagnostics
test-memory:
    {{cargo_bin}} test -p zenith-tests --test memory_vmrss -- --nocapture

# Run entire QA test suite via nix develop
qa:
    nix develop --command cargo test --workspace -- --nocapture

# Build optimized release binary
build:
    cargo build --release -p zenith-cli

# Package and build via Nix Flake
nix-build:
    nix build .#zenith-shell

# Format codebase
fmt:
    cargo fmt --all
