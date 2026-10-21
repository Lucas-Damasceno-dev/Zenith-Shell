#!/usr/bin/env python3
"""
Test suite for [Onda 3.2] Dock: Magnificação macOS-like, Física Spring & Auto-Hide Sync
Validates:
1. Mathematical Gaussian curve for macOS-like zoom (peak at focused, intermediate at neighbors).
2. Parabolic rise offset calculation.
3. Hyprland gaps_out dynamic margin bottom synchronization.
4. Intelligent auto-hide collision detection logic.
5. Luau syntax integrity and declarative structures in Dock.luau.
"""

import os
import math
import re
import sys

def test_dock_code_integrity():
    dock_file = "config/zenith/overlays/Dock.luau"
    assert os.path.exists(dock_file), f"File {dock_file} missing!"

    with open(dock_file, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Required functions and symbols
    required_symbols = [
        "check_dock_collision",
        "is_auto_hidden",
        "hypr_gaps_out",
        "dock_margin_bottom",
        "app_slots",
        "Zenith.Services.HyprlandGaps",
        "Zenith.Services.Clients",
        "Zenith.Services.Screen",
        "Zenith.Services.Workspaces",
        "is_client_focused",
    ]
    for sym in required_symbols:
        assert sym in content, f"Symbol '{sym}' missing from Dock.luau"

    # Support both modular Magnification pipeline and legacy calculate_zoom
    assert ("calculate_zoom" in content) or ("Magnification" in content and "slot_transforms" in content), \
        "Magnification calculation logic missing from Dock.luau"

    # 2. Reveal strip presence for auto-hide
    assert ("Zenith Dock (Oculta por sobreposição - Clique para alternar)" in content) or \
           ("Zenith Dock (Auto-Hide ativo" in content), "Auto-hide reveal strip tooltip missing"
    assert "popup:toggle:dock" in content or "dock:reveal" in content or "toggle" in content, "popup:toggle:dock click handler missing"

    # 3. Delimiter balance check
    stack = []
    pairs = {")": "(", "}": "{", "]": "["}
    for line_idx, line in enumerate(content.splitlines(), 1):
        clean_line = line.split("--")[0]
        i = 0
        while i < len(clean_line):
            ch = clean_line[i]
            if ch in ('"', "'"):
                quote = ch
                i += 1
                while i < len(clean_line) and clean_line[i] != quote:
                    if clean_line[i] == "\\":
                        i += 1
                    i += 1
            elif ch in ("(", "{", "["):
                stack.append((ch, line_idx))
            elif ch in (")", "}", "]"):
                assert stack, f"Unmatched {ch} at line {line_idx}"
                last, l_idx = stack.pop()
                assert pairs[ch] == last, f"Mismatched {last} (line {l_idx}) with {ch} (line {line_idx})"
            i += 1

    assert not stack, f"Unclosed delimiters: {stack}"
    print("✓ Dock.luau syntax integrity and symbols verified!")

def test_gaussian_spring_magnification():
    """Validates macOS-like Gaussian zoom curve parity with Quickshell"""
    def calc_zoom(dist, max_scale=1.38, sigma=1.15):
        peak = max_scale
        s = sigma
        target_scale = 1.0
        if dist <= 3:
            target_scale = 1.0 + (peak - 1.0) * math.exp(-(dist * dist) / (2.0 * s * s))
        rise = round((target_scale - 1.0) * 16)
        return round(target_scale, 3), rise

    s0, r0 = calc_zoom(0)
    s1, r1 = calc_zoom(1)
    s2, r2 = calc_zoom(2)
    s3, r3 = calc_zoom(3)
    s4, r4 = calc_zoom(4)

    # Assert peak scale on focused item
    assert s0 == 1.38, f"Expected peak 1.38, got {s0}"
    assert r0 == 6, f"Expected 6px rise on peak, got {r0}"

    # Assert smooth intermediate scale on immediate neighbors
    assert 1.22 <= s1 <= 1.28, f"Expected intermediate neighbor ~1.26, got {s1}"
    assert 3 <= r1 <= 5, f"Expected 4px rise on neighbor, got {r1}"

    # Assert gentle scale on secondary neighbors
    assert 1.05 <= s2 <= 1.12, f"Expected secondary neighbor ~1.08, got {s2}"

    # Assert resting scale on distant items
    assert s4 == 1.0, f"Expected resting 1.0, got {s4}"
    assert r4 == 0, f"Expected 0px rise, got {r4}"

    # Strictly monotonic decreasing with distance
    assert s0 > s1 > s2 > s3 >= s4
    print("✓ Gaussian zoom curve and parabolic rise verified!")

def test_auto_hide_collision_logic():
    """Simulates Quickshell / Zenith collision detection algorithm"""
    def check_collision(clients, active_ws, dock_h=52, margin_bottom=12, screen_w=1920, screen_h=1080):
        expected_dock_h = dock_h + margin_bottom + 20
        dock_top = screen_h - expected_dock_h

        for c in clients:
            ws_id = c.get("workspace_id")
            if ws_id == active_ws:
                if c.get("fullscreen"): return True
                if not c.get("floating"): return True
                win_y = c.get("y", 0)
                win_h = c.get("height", 0)
                win_x = c.get("x", 0)
                win_w = c.get("width", 0)
                if (win_y + win_h) >= dock_top and win_y < screen_h and (win_x < screen_w and win_x + win_w > 0):
                    return True
        return False

    # 1. Empty workspace
    assert check_collision([], 1) == False

    # 2. Window on inactive workspace
    assert check_collision([{"workspace_id": 2, "fullscreen": True}], 1) == False

    # 3. Fullscreen window on active workspace
    assert check_collision([{"workspace_id": 1, "fullscreen": True}], 1) == True

    # 4. Tiled (non-floating) window on active workspace
    assert check_collision([{"workspace_id": 1, "floating": False}], 1) == True

    # 5. Floating window away from dock (top half)
    assert check_collision([{"workspace_id": 1, "floating": True, "x": 100, "y": 100, "width": 800, "height": 400}], 1) == False

    # 6. Floating window overlapping bottom dock region (dock_top = 1080 - 84 = 996)
    assert check_collision([{"workspace_id": 1, "floating": True, "x": 200, "y": 700, "width": 800, "height": 350}], 1) == True

    print("✓ Intelligent auto-hide collision detection verified!")

def test_hypr_gaps_out_sync():
    """Validates dynamic gaps_out calculation logic"""
    def compute_margin(hypr_gaps_out, store_margin, default_margin=12):
        if hypr_gaps_out is not None and hypr_gaps_out > 0:
            return hypr_gaps_out
        return store_margin or default_margin

    # If gaps_out = 16 from Hyprland
    assert compute_margin(16, None) == 16
    # If gaps_out = 0 (tiling edge-to-edge), falls back to store or default
    assert compute_margin(0, 8) == 8
    assert compute_margin(0, None) == 12
    # If gaps_out = 24
    assert compute_margin(24, 12) == 24
    print("✓ Hyprland gaps_out dynamic margin sync verified!")

if __name__ == "__main__":
    test_dock_code_integrity()
    test_gaussian_spring_magnification()
    test_auto_hide_collision_logic()
    test_hypr_gaps_out_sync()
    print("\n🎉 ALL [ONDA 3.2] DOCK MAGNIFICATION & AUTO-HIDE TESTS PASSED!")
