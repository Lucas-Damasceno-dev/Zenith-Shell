#!/usr/bin/env python3
import os
import sys
import socket
import json
import time
import subprocess
import threading
import glob
from pathlib import Path

# --- Configuration ---
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
HYPR_SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
OUTPUT_FILE = "/tmp/quickshell_context.json"
DEBUG = False

# Icons for contexts
ICONS = {
    "rust": "",  # nf-dev-rust
    "node": "",  # nf-dev-nodejs_small
    "python": "",  # nf-dev-python
    "nix": "",   # nf-linux-nixos
    "go": "",    # nf-seti-go
    "c": "",     # nf-custom-c
    "cpp": "",   # nf-custom-cpp
    "git": "",   # nf-dev-git
    "docker": "", # nf-linux-docker
    "default": "" # nf-oct-terminal
}

# Border colors for Hyprland
HYPR_COLORS = {
    "rust": "rgb(e43717)",
    "node": "rgb(68a063)",
    "nix": "rgb(7e7eff)",
    "python": "rgb(ffde57)",
    "go": "rgb(00add8)",
    "c": "rgb(555555)",
    "cpp": "rgb(f34b7d)",
    "git": "rgb(f14e32)",
    "docker": "rgb(2496ed)",
    "default": "rgb(a7c080)"
}
last_applied_color = ""

def update_hypr_border(project_type):
    global last_applied_color
    color = HYPR_COLORS.get(project_type, HYPR_COLORS["default"])
    if color != last_applied_color:
        try:
            # Send command asynchronously (fire and forget)
            subprocess.Popen(["hyprctl", "keyword", "general:col.active_border", f"{color} 45deg"], 
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            last_applied_color = color
        except:
            pass

def check_git_branch(path):
    try:
        res = subprocess.run(["git", "branch", "--show-current"], cwd=path, capture_output=True, text=True, timeout=1)
        if res.returncode == 0:
            return res.stdout.strip()
    except:
        pass
    return ""

def check_git_status_dirty(path):
    try:
        res = subprocess.run(["git", "status", "--porcelain"], cwd=path, capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            return len(res.stdout.strip()) > 0
    except:
        pass
    return False

def read_project_notes(path):
    try:
        notes_path = path / ".project-notes"
        if notes_path.exists():
            with open(notes_path, "r") as f:
                return f.read(2048) # Limit size
    except:
        pass
    return ""

# Cache for expensive operations
class Cache:
    def __init__(self):
        self._git_cache = {} # path -> (timestamp, branch, dirty)
        self._git_ttl = 5.0 # seconds
        self._agenda_cache = (0, []) # timestamp, events
        self._agenda_ttl = 900.0 # 15 minutes
        self._lock = threading.Lock()

    def get_git_info(self, path):
        now = time.time()
        path_str = str(path)
        
        with self._lock:
            if path_str in self._git_cache:
                ts, branch, dirty = self._git_cache[path_str]
                # If cache is valid, return it
                if now - ts < self._git_ttl:
                    return branch, dirty
                # If cache expired, trigger background update
                threading.Thread(target=self.update_git_bg, args=(path,)).start()
                return branch, dirty
        
        # First time: blocking update (or return empty and trigger bg)
        # Let's do blocking first time to avoid flicker, but with short timeout
        return self._do_update(path)

    def get_agenda(self):
        now = time.time()
        ts, events = self._agenda_cache
        
        if now - ts > self._agenda_ttl:
             # Trigger background update
             threading.Thread(target=self.update_agenda_bg).start()
        
        return events

    def update_git_bg(self, path):
        self._do_update(path)

    def update_agenda_bg(self):
        events = check_khal_agenda()
        with self._lock:
            self._agenda_cache = (time.time(), events)

    def _do_update(self, path):
        branch = check_git_branch(path)
        dirty = check_git_status_dirty(path)
        with self._lock:
            self._git_cache[str(path)] = (time.time(), branch, dirty)
        return branch, dirty

def check_khal_agenda():
    try:
        # Check if khal is installed
        if subprocess.run(["which", "khal"], stdout=subprocess.DEVNULL).returncode != 0:
            return []
            
        cmd = ["khal", "list", "now", "7days", "--format", "{title}||{start-date} {start-time}||{end-time}"]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if res.returncode == 0:
            events = []
            for line in res.stdout.splitlines():
                parts = line.split("||")
                if len(parts) >= 2:
                    events.append({"title": parts[0].strip(), "start": parts[1].strip(), "end": parts[2].strip() if len(parts) > 2 else ""})
            return events[:5]
    except:
        pass
    return []

cache = Cache()

current_state = {
    "context": "desktop",
    "path": str(Path.home()),
    "icon": "",
    "project_type": None,
    "git_branch": None,
    "git_dirty": False,
    "notes": "",
    "agenda": [],
    "issues": [],
    "issue_count": 0,
    "diagnostics": {"errors": 0, "warnings": 0},
    "status": "ok"  # ok, warning, error
}

def log(msg):
    if DEBUG:
        print(f"[CTX] {msg}", file=sys.stderr)

def get_hyprland_socket():
    if not HYPR_SIG:
        return None
    return f"{RUNTIME_DIR}/hypr/{HYPR_SIG}/.socket2.sock"

def get_active_window_pid():
    try:
        # Hyprland activewindow -j returns json with pid
        result = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True)
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        return data.get("pid")
    except Exception as e:
        log(f"Error getting active window: {e}")
        return None

def get_process_children(pid):
    """Returns a list of child PIDs for a given PID."""
    try:
        # Read /proc/pid/task/tid/children or use pgrep
        # Using pgrep is safer/easier across linux versions if proc is complex
        res = subprocess.run(["pgrep", "-P", str(pid)], capture_output=True, text=True)
        if res.returncode == 0:
            return [int(x) for x in res.stdout.split()]
    except:
        pass
    return []

def get_deepest_cwd(pid):
    """
    Traverses the process tree from the window PID downwards to find the most relevant process.
    Prioritizes known editors or shells.
    """
    if not pid:
        return Path.home()
    
    # Simple BFS to find all descendants
    queue = [pid]
    descendants = []
    
    while queue:
        curr = queue.pop(0)
        descendants.append(curr)
        children = get_process_children(curr)
        queue.extend(children)
    
    # Filter descendants: we want the one that looks like an editor or shell
    # For now, let's just take the deepest one that has a valid CWD
    # In a real scenario, we might want to prioritize 'nvim' or 'vim' processes
    
    best_cwd = None
    best_depth = -1
    
    for proc_pid in reversed(descendants): # Start from deepest
        try:
            p = Path(f"/proc/{proc_pid}")
            if not p.exists(): continue
            
            # Read cmdline to see what it is
            with open(p / "cmdline", "rb") as f:
                cmdline = f.read().replace(b'\0', b' ').decode('utf-8', errors='ignore')
            
            # Read cwd
            cwd = os.readlink(p / "cwd")
            
            log(f"Checking PID {proc_pid}: {cmdline} -> {cwd}")
            
            # Heuristic: If it's a shell or editor, it's likely our guy.
            # If we found nvim, that's a winner.
            if "nvim" in cmdline or "vim" in cmdline:
                return Path(cwd)
            
            if best_cwd is None:
                best_cwd = Path(cwd)
                
        except (PermissionError, FileNotFoundError, OSError):
            continue
            
    return best_cwd if best_cwd else Path.home()

def detect_project_context(path):
    path = Path(path)
    if not path.exists():
        return "desktop", None, ""

    files = []
    try:
        files = [f.name for f in path.iterdir() if f.is_file()]
    except:
        pass

    icon = ICONS["default"]
    p_type = "directory"
    
    if "Cargo.toml" in files:
        return "project", "rust", ICONS["rust"]
    elif "package.json" in files:
        return "project", "node", ICONS["node"]
    elif "flake.nix" in files:
        return "project", "nix", ICONS["nix"]
    elif "requirements.txt" in files or "pyproject.toml" in files:
        return "project", "python", ICONS["python"]
    elif "go.mod" in files:
        return "project", "go", ICONS["go"]
    elif "Makefile" in files:
        return "project", "c", ICONS["c"]
    elif ".git" in files or (path / ".git").is_dir():
        return "project", "git", ICONS["git"]
        
    return "directory", "generic", ICONS["default"]

def scan_journal_errors():
    """
    Passively scans journalctl for recent critical errors.
    Returns a list of issues.
    """
    issues = []
    try:
        # Get last 5 lines of err/crit priority
        cmd = ["journalctl", "-p", "3", "-n", "5", "--output", "json", "--no-pager"]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                try:
                    entry = json.loads(line)
                    msg = entry.get("MESSAGE", "Unknown error")
                    unit = entry.get("_SYSTEMD_UNIT", "system")
                    issues.append({"source": unit, "message": msg, "severity": "error"})
                except:
                    pass
    except:
        pass
    return issues

def scan_nvim_diagnostics():
    """
    Reads diagnostics exported by Neovim from /tmp/nvim_diag.json
    """
    diag = {"errors": 0, "warnings": 0}
    try:
        p = Path("/tmp/nvim_diag.json")
        if p.exists():
            with open(p, "r") as f:
                data = json.load(f)
                diag["errors"] = data.get("errors", 0)
                diag["warnings"] = data.get("warnings", 0)
    except:
        pass
    return diag

def update_state():
    global current_state
    
    pid = get_active_window_pid()
    cwd = get_deepest_cwd(pid)
    
    ctx_type, proj_type, icon = detect_project_context(cwd)
    
    # Update Hyprland border color
    update_hypr_border(proj_type if ctx_type == "project" else "default")
    
    branch = ""
    dirty = False
    notes = ""
    
    if ctx_type == "project":
        branch, dirty = cache.get_git_info(cwd)
        notes = read_project_notes(cwd)
    
    agenda = cache.get_agenda()
    sys_issues = scan_journal_errors()
    nvim_diag = scan_nvim_diagnostics()
    
    # Merge issues
    total_issues = len(sys_issues) + nvim_diag["errors"]
    status = "ok"
    if total_issues > 0:
        status = "error"
    elif nvim_diag["warnings"] > 0:
        status = "warning"
    
    new_state = {
        "context": ctx_type,
        "path": str(cwd),
        "icon": icon,
        "project_type": proj_type,
        "git_branch": branch,
        "git_dirty": dirty,
        "notes": notes,
        "agenda": agenda,
        "issues": sys_issues,
        "issue_count": total_issues,
        "diagnostics": nvim_diag,
        "status": status,
        "timestamp": time.time()
    }
    
    current_state = new_state
    print_state(new_state)

def print_state(data):
    try:
        print(json.dumps(data), flush=True)
    except Exception as e:
        log(f"Failed to print state: {e}")

# DEPRECATED: use context_daemon_v2.py instead.
# Kept for reference only; recursive reconnect replaced with iterative loop.
def listen_socket():
    sock_path = get_hyprland_socket()
    if not sock_path:
        log("Hyprland socket not found")
        return

    update_state()  # Initial update

    while True:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            client.connect(sock_path)
            log("Connected to Hyprland socket")

            last_update = 0
            min_interval = 0.25  # 250ms debounce

            while True:
                data = client.recv(1024)
                if not data:
                    break

                msg = data.decode('utf-8', errors='ignore')
                if "activewindow>>" in msg:
                    now = time.time()
                    if now - last_update > min_interval:
                        time.sleep(0.1)  # Wait for process tree
                        update_state()
                        last_update = time.time()

        except KeyboardInterrupt:
            return
        except Exception as e:
            log(f"Socket error: {e}")
            time.sleep(5)
        finally:
            try:
                client.close()
            except Exception:
                pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        print("ok")
        raise SystemExit(0)
    listen_socket()
