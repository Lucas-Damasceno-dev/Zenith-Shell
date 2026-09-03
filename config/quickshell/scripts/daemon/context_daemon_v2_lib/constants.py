from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

RUNTIME_DIR: str = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
HYPR_SIG: str | None = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
CACHE_DIR: str = os.path.expanduser("~/.cache")
_COLOR_PATH_CANDIDATES: tuple[str, ...] = (
    os.path.join(CACHE_DIR, "quickshell/matugen/colors.json"),
    os.path.join(CACHE_DIR, "matugen/colors.json"),
)


def _resolve_colors_file() -> str:
    for candidate in _COLOR_PATH_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    return _COLOR_PATH_CANDIDATES[0]


def _resolve_quickshell_bin() -> str:
    env_bin = os.environ.get("QUICKSHELL_BIN", "").strip()
    candidates: list[str] = []
    if env_bin:
        candidates.append(env_bin)

    which_bin = shutil.which("quickshell")
    if which_bin:
        candidates.append(which_bin)

    home = str(Path.home())
    user = os.environ.get("USER", "")
    candidates.extend([
        os.path.join(home, ".nix-profile/bin/quickshell"),
        f"/etc/profiles/per-user/{user}/bin/quickshell" if user else "",
        "/nix/var/nix/profiles/default/bin/quickshell",
        "/run/current-system/sw/bin/quickshell",
    ])

    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    return env_bin or "quickshell"


COLORS_FILE: str = _resolve_colors_file()
COMMAND_SOCKET: str = os.path.join(RUNTIME_DIR, "quickshell_commands.sock")
DEBUG: bool = os.environ.get("CONTEXT_DAEMON_DEBUG", "0") == "1"
QUICKSHELL_BIN: str = _resolve_quickshell_bin()

MONITORED_SERVICES: dict[str, str] = {
    "quickshell.service": "Quickshell",
    "pipewire.service": "PipeWire",
    "wireplumber.service": "WirePlumber",
    "xdg-desktop-portal.service": "Portal",
    "xdg-desktop-portal-hyprland.service": "Portal Hyprland",
    "hypridle.service": "Hypridle",
}

ICONS: dict[str, str] = {
    "rust": "\ue7a8",
    "node": "\ue718",
    "python": "\ue73c",
    "nix": "\uf313",
    "go": "\ue627",
    "c": "\ue61e",
    "cpp": "\ue61d",
    "git": "\ue702",
    "docker": "\ue7b0",
    "default": "\uf15b",
}

WINDOW_CLASSES_WITH_CWD = frozenset(["kitty", "alacritty", "foot", "code", "neovide", "emacs"])

_CMD_ALLOWED_ACTIONS = frozenset(["restart_service", "quick_fix"])
_CMD_ALLOWED_KEYS = frozenset(["action", "target"])
_CMD_MAX_BYTES = 4096


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--self-test":
    print("ok")
    raise SystemExit(0)
