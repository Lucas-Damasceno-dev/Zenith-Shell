"""
Validation test suite for [Onda 3.1] Dock Context Menu, Window Actions & Multi-Client (t_356a6084)
"""
import re
import sys

def test_dock_context_menu_and_multiclient():
    with open("config/zenith/overlays/Dock.luau", "r", encoding="utf-8") as f:
        content = f.read()

    print("Checking [Onda 3.1] Dock Implementation...")

    # 1. Multi-client support
    assert "get_app_clients" in content, "Missing get_app_clients definition"
    assert "check_app_clients_focus" in content, "Missing check_app_clients_focus definition"
    assert "build_indicator" in content, "Missing build_indicator definition"
    assert "app_clients" in content, "Missing app_clients in AppSlot and DockItem"
    assert "unpinned_groups" in content, "Missing unpinned_groups grouping logic for multi-client unpinned apps"
    print("✓ Multi-client support verified (app_clients, grouped unpinned apps, build_indicator)")

    # 2. Window action: Alternar janela ativa / minimizar ao clicar no item focado
    assert "get_click_action" in content, "Missing get_click_action definition"
    assert "focus:" in content, "Missing focus: action for cycling through multi-client windows"
    assert "window:toggle_minimize:" in content, "Missing window:toggle_minimize: for minimizing focused single window"
    assert "next_idx = (focused_idx % count) + 1" in content or "(focused_idx % count) + 1" in content, "Missing cyclic instance switcher logic"
    print("✓ Alternating active window / minimize on focused item verified")

    # 3. Context Menu Actions
    assert "Nova Janela" in content, "Missing 'Nova Janela' context menu action"
    assert "Fechar Janela" in content, "Missing 'Fechar Janela' context menu action"
    assert "Fixar na Dock" in content, "Missing 'Fixar na Dock' context menu action"
    assert "Desafixar da Dock" in content, "Missing 'Desafixar da Dock' context menu action"
    assert "hyprctl dispatch closewindow address:" in content, "Missing closewindow address command"
    assert "toggle_pin" in content, "Missing toggle_pin function"
    assert "dock_pinned_apps" in content, "Missing dock_pinned_apps persistence key"
    assert "dock_context_app" in content, "Missing dock_context_app storage key"
    print("✓ Context menu actions verified (Nova Janela, Fechar Janela, Fixar/Desafixar da Dock)")

    # 4. Check syntax balance with python parser
    from test_luau_syntax import check_file
    assert check_file("config/zenith/overlays/Dock.luau"), "Dock.luau failed syntax check"
    print("✓ Luau syntax integrity verified")

    print("\n🎉 ALL [ONDA 3.1] DOCK CONTEXT MENU & MULTI-CLIENT TESTS PASSED!")

if __name__ == "__main__":
    test_dock_context_menu_and_multiclient()
