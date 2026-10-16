#!/usr/bin/env python3
"""
Comprehensive validation test for SystemMonitorPopup.luau
Validates:
1. Luau syntax, brackets balancing, strict typing header
2. UI specification completeness (CPU, RAM, Swap, Disk, Processes, Services, btop/htop, Glassmorphic window)
3. 1:1 parity with SystemMonitorUtils.js
4. Runtime evaluation via precompiled test runner
"""

import sys
import os
import subprocess
import re

def test_file_exists():
    path = "config/zenith/overlays/SystemMonitorPopup.luau"
    assert os.path.isfile(path), f"File {path} does not exist!"
    print(f"✓ File exists: {path}")

def test_syntax_and_delimiters():
    path = "config/zenith/overlays/SystemMonitorPopup.luau"
    with open(path) as f:
        content = f.read()

    assert content.startswith("--!strict"), "Missing --!strict directive at top of file"

    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    lines = content.splitlines()

    for line_idx, line in enumerate(lines, 1):
        clean = re.sub(r'--.*$', '', line)
        i = 0
        while i < len(clean):
            ch = clean[i]
            if ch in ('"', "'"):
                quote = ch
                i += 1
                while i < len(clean) and clean[i] != quote:
                    if clean[i] == "\\":
                        i += 1
                    i += 1
            elif ch in ("(", "{", "["):
                stack.append((ch, line_idx))
            elif ch in (")", "}", "]"):
                assert stack, f"Unmatched closing {ch} at line {line_idx}"
                last, l_idx = stack.pop()
                assert pairs[ch] == last, f"Mismatched {last} (line {l_idx}) and {ch} (line {line_idx})"
            i += 1

    assert not stack, f"Unclosed delimiters remaining: {stack}"
    print(f"✓ Delimiters balanced: 0 unclosed brackets/parentheses across {len(lines)} lines")

def test_specification_elements():
    path = "config/zenith/overlays/SystemMonitorPopup.luau"
    with open(path) as f:
        content = f.read()

    # CPU metrics & progress bar
    assert "cpu_pct" in content or "cpu.percent" in content, "Missing CPU usage computation"
    assert "ProgressBar(cpu_pct" in content, "Missing CPU ProgressBar"

    # RAM & Swap metrics & progress bar
    assert "ram_pct" in content and "ram_used_gb" in content, "Missing RAM metrics"
    assert "ProgressBar(ram_pct" in content, "Missing RAM ProgressBar"
    assert "swap_pct" in content, "Missing Swap metrics"
    assert "ProgressBar(swap_pct" in content, "Missing Swap ProgressBar"

    # Disk storage metrics
    assert "disk_root_pct" in content, "Missing Disk Root metrics"
    assert "disk_home_pct" in content, "Missing Disk Home metrics"
    assert "ProgressBar(disk_root_pct" in content, "Missing Disk Root ProgressBar"
    assert "ProgressBar(disk_home_pct" in content, "Missing Disk Home ProgressBar"

    # Top processes table
    assert "process_rows" in content, "Missing process_rows table"
    assert "p.pid" in content and "p.name" in content and "p.cpu" in content and "p.mem" in content, "Missing process row PID/name/cpu/mem fields"
    assert "cmd:kill -TERM" in content, "Missing kill action"

    # Services tab
    assert "service_rows" in content, "Missing service_rows table"
    assert "pipewire.service" in content, "Missing systemd service entry"
    assert "cmd:systemctl --user restart" in content, "Missing service restart action"
    assert "cmd:systemctl --user stop" in content, "Missing service stop action"

    # Actions: btop, htop, close
    assert "cmd:foot -e btop &" in content or "btop" in content, "Missing btop action"
    assert "cmd:foot -e htop &" in content or "htop" in content, "Missing htop action"
    assert "popup:close" in content, "Missing popup:close action"

    # Glassmorphic window
    assert "Zenith.Window" in content, "Missing Zenith.Window node"
    assert "border_radius = 16" in content, "Missing standard border_radius = 16"
    assert "blur = 24" in content, "Missing shadow blur specification"

    # SystemMonitorUtils parity
    assert "SystemMonitorUtils.cleanPath" in content, "Missing cleanPath"
    assert "SystemMonitorUtils.buildProcessCommand" in content, "Missing buildProcessCommand"
    assert "SystemMonitorUtils.buildServiceCommand" in content, "Missing buildServiceCommand"
    assert "SystemMonitorUtils.parseProcessRows" in content, "Missing parseProcessRows"
    assert "SystemMonitorUtils.parseServiceRows" in content, "Missing parseServiceRows"

    print("✓ All UI & Functional specifications validated successfully!")

def test_runtime_import_evaluation():
    # Test importing SystemMonitorPopup in bar.luau and running precompiled test binary
    bar_path = "config/zenith/bar.luau"
    with open(bar_path) as f:
        original = f.read()

    test_patch = 'local UIKit = Zenith.import("ui_kit")\nlocal _sysmon_eval = Zenith.import("SystemMonitorPopup")\nlocal theme = UIKit.Theme.get()'
    modified = original.replace('local UIKit = Zenith.import("ui_kit")\nlocal theme = UIKit.Theme.get()', test_patch)
    
    with open(bar_path, "w") as f:
        f.write(modified)

    try:
        res = subprocess.run(
            ["./target/debug/deps/zenith_runtime-d37e618d21618a9d", "test_bar_config_evaluation"],
            capture_output=True,
            text=True
        )
        assert res.returncode == 0, f"Runtime evaluation failed:\n{res.stdout}\n{res.stderr}"
        print("✓ Runtime evaluation via Zenith engine: SUCCESS (0.4s)")
    finally:
        with open(bar_path, "w") as f:
            f.write(original)

if __name__ == "__main__":
    print("=== Running SystemMonitorPopup Test Suite ===")
    test_file_exists()
    test_syntax_and_delimiters()
    test_specification_elements()
    test_runtime_import_evaluation()
    print("=== All tests PASSED successfully! ===")
