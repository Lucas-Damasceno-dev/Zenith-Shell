#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
  command -v python3 >/dev/null 2>&1 || { echo "missing python3"; exit 1; }
  echo "ok"
  exit 0
fi

python3 - <<'PYEOF'
import json
import subprocess
import glob
import sys
import os

def get_privacy_state():
    mic_apps = set()
    cam_apps = set()
    screen_apps = set()

    # 1. PipeWire Node Inspection via pw-dump
    try:
        pw_proc = subprocess.run(
            ["pw-dump"],
            capture_output=True,
            text=True,
            timeout=1.2
        )
        if pw_proc.returncode == 0 and pw_proc.stdout.strip():
            nodes = json.loads(pw_proc.stdout)
            for item in nodes:
                if item.get("type") != "PipeWire:Interface:Node":
                    continue
                props = item.get("info", {}).get("props", {})
                media_class = props.get("media.class") or ""
                app_name = (
                    props.get("application.name")
                    or props.get("node.name")
                    or props.get("client.name")
                    or props.get("application.process.binary")
                    or "App"
                )
                app_lower = app_name.lower()

                # Ignore internal quickshell/wireplumber self-monitors
                if "quickshell" in app_lower or "wireplumber" in app_lower:
                    continue

                # Microphone input stream (recording / voice chat)
                if media_class == "Stream/Input/Audio":
                    clean_name = app_name.replace(" input", "").replace(" Input", "")
                    mic_apps.add(clean_name if clean_name else app_name)

                # Camera input stream
                elif media_class == "Stream/Input/Video":
                    cam_apps.add(app_name)

                # Screen casting / portal stream
                elif media_class in ("Stream/Output/Video", "Stream/Input/Video"):
                    node_name = (props.get("node.name") or "").lower()
                    if "screencast" in node_name or "portal" in node_name:
                        screen_apps.add(app_name if app_name != "App" else "Screencast")
    except Exception:
        pass

    # 2. Camera Device Inspection via /proc/*/fd (Catches direct V4L2 users like Brave/Chromium/OBS)
    try:
        for fd_link in glob.glob("/proc/[0-9]*/fd/*"):
            try:
                target = os.readlink(fd_link)
                if target.startswith("/dev/video"):
                    pid = fd_link.split("/")[2]
                    with open(f"/proc/{pid}/comm", "r") as f:
                        comm = f.read().strip()
                    if comm not in ("wireplumber", "pipewire", "pipewire-pulse", "quickshell"):
                        # Format name nicely (e.g., brave -> Brave)
                        formatted = comm.capitalize() if comm.islower() else comm
                        cam_apps.add(formatted)
            except Exception:
                pass
    except Exception:
        pass

    # 3. Known CLI and standalone Screen Recorders
    recorders = [
        "wf-recorder",
        "obs",
        "obs-studio",
        "gpu-screen-recorder",
        "wl-screenrec",
        "kooha",
        "simplescreenrecorder",
        "recordmydesktop"
    ]
    try:
        pgrep_proc = subprocess.run(
            ["pgrep", "-a", "-x", "|".join(recorders)],
            capture_output=True,
            text=True,
            timeout=0.8
        )
        if pgrep_proc.returncode == 0:
            for line in pgrep_proc.stdout.strip().splitlines():
                parts = line.split(None, 1)
                if len(parts) > 1:
                    raw_cmd = parts[1].split()[0]
                    clean_name = os.path.basename(raw_cmd)
                    screen_apps.add(clean_name)
                elif len(parts) == 1:
                    screen_apps.add(parts[0])
    except Exception:
        pass

    mic_list = sorted(list(mic_apps))
    cam_list = sorted(list(cam_apps))
    screen_list = sorted(list(screen_apps))

    state = {
        "mic": {
            "active": len(mic_list) > 0,
            "apps": mic_list
        },
        "camera": {
            "active": len(cam_list) > 0,
            "apps": cam_list
        },
        "screen": {
            "active": len(screen_list) > 0,
            "apps": screen_list
        },
        "any": bool(mic_list or cam_list or screen_list)
    }
    print(json.dumps(state))

if __name__ == "__main__":
    get_privacy_state()
PYEOF
