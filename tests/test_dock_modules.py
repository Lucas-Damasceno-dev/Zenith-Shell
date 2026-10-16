#!/usr/bin/env python3
"""
Test validation suite for Dock embedded modules (MPRIS Pill, Trash & Quick Utilities)
Checks Luau syntax, declarative structures, and required callbacks.
"""

import os
import re
import sys

def test_dock_overlay():
    dock_path = "config/zenith/overlays/Dock.luau"
    assert os.path.exists(dock_path), f"File {dock_path} does not exist"

    with open(dock_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Check module components defined
    assert "local function DockUtilities" in content, "DockUtilities function missing"
    assert "local function DockMprisPill" in content, "DockMprisPill function missing"
    assert "local function DockTrash" in content, "DockTrash function missing"

    # 2. Check MPRIS Pill features
    assert "media:play-pause" in content, "media:play-pause action missing"
    assert "media:previous" in content, "media:previous action missing"
    assert "media:next" in content, "media:next action missing"
    assert "display_title" in content, "display_title variable missing"
    assert "display_artist" in content, "display_artist variable missing"
    assert "album_art_box" in content, "album_art_box missing"

    # 3. Check Trash features
    assert "trash-empty" in content, "trash-empty action missing"
    assert "trash:///" in content, "trash:/// action missing"
    assert "󰩺" in content, "Reactive full trash icon missing"
    assert "󰩹" in content, "Reactive empty trash icon missing"

    # 4. Check Quick Utilities features
    assert "quick-term" in content, "Quick terminal action missing"
    assert "screenshot:area" in content, "Screenshot area action missing"
    assert "screenshot:full" in content, "Screenshot full action missing"

    # 5. Check Brackets balance
    stack = []
    for line_no, line in enumerate(content.splitlines(), 1):
        clean_line = line.split("--")[0]
        for ch in clean_line:
            if ch in "({[":
                stack.append((ch, line_no))
            elif ch in ")}]":
                assert len(stack) > 0, f"Unmatched closing bracket {ch} at line {line_no}"
                open_ch, _ = stack.pop()
                expected = {"(": ")", "{": "}", "[": "]"}[open_ch]
                assert ch == expected, f"Mismatched bracket {open_ch} closed with {ch} at line {line_no}"

    assert len(stack) == 0, f"Unclosed brackets: {stack}"
    print("test_dock_overlay passed successfully!")

def test_dock_entrypoint():
    entry_path = "config/zenith/dock.luau"
    assert os.path.exists(entry_path), f"File {entry_path} does not exist"

    with open(entry_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "Zenith.import(\"overlays/Dock\")" in content or "Zenith.import('overlays/Dock')" in content
    assert "return Dock" in content
    print("test_dock_entrypoint passed successfully!")

if __name__ == "__main__":
    test_dock_overlay()
    test_dock_entrypoint()
    print("ALL DOCK MODULE TESTS PASSED!")
