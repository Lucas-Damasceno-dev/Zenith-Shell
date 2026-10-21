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

# Single Compiler Gatekeeper: serialized cargo check via file lock to avoid lock contention
gate-check:
    flock -w 120 /tmp/zenith_cargo.lock {{cargo_bin}} check --workspace

# Single Compiler Gatekeeper: serialized cargo test via file lock
gate-test:
    flock -w 180 /tmp/zenith_cargo.lock {{cargo_bin}} test --workspace

# Single Compiler Gatekeeper: run headless off-screen test suites
gate-headless:
    flock -w 180 /tmp/zenith_cargo.lock {{cargo_bin}} test -p zenith-tests --test headless_suites -- --nocapture

# Single Compiler Gatekeeper: run hot-reload latency benchmarks (< 10ms SLA)
gate-bench:
    flock -w 180 /tmp/zenith_cargo.lock {{cargo_bin}} test -p zenith-tests --test bench_hot_reload -- --nocapture

# Single Compiler Gatekeeper: run VmRSS stability tests (< 15MB SLA)
gate-memory:
    flock -w 180 /tmp/zenith_cargo.lock {{cargo_bin}} test -p zenith-tests --test memory_vmrss -- --nocapture

# Fast-path for UI/Luau agents: static assertions without triggering Cargo locks
test-fast:
    python3 tests/validate_custom_suite.py
    python3 tests/test_luau_syntax.py
    python3 tests/test_dock_magnification.py

# Isolated per-agent fast-check: 100% parallel with zero lock contention
agent-check agent crate="":
    CARGO_TARGET_DIR=target/agents/{{agent}} {{cargo_bin}} check {{ if crate != "" { "-p " + crate } else { "" } }}

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
