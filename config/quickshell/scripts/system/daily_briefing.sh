#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
QS_STATE_DIR="${HOME}/.local/state/quickshell"
WEATHER_CACHE="${QS_STATE_DIR}/weather-cache.json"
TODO_FILE="${QS_STATE_DIR}/calendar-todo.json"
QS_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/quickshell"
NOTES_FILE="${QS_DATA_DIR}/notes.json"
NOTIFY=false

# ─── Argument parsing ────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --notify) NOTIFY=true ;;
  esac
done

if [[ "${1:-}" == "--self-test" ]]; then
  command -v python3 >/dev/null 2>&1 || { echo "missing python3"; exit 1; }
  echo "ok"
  exit 0
fi

# ─── Delegate heavy lifting to a single Python call ──────────────────────────
python3 - "$QS_STATE_DIR" "$WEATHER_CACHE" "$TODO_FILE" "$NOTES_FILE" "$NOTIFY" <<'PYEOF'
import json, sys, os, shutil, subprocess
from datetime import date, datetime

qs_state_dir = sys.argv[1]
weather_cache_path = sys.argv[2]
todo_file_path = sys.argv[3]
notes_file_path = sys.argv[4]
notify_enabled = len(sys.argv) > 5 and sys.argv[5] == "true"

# ── Greeting ─────────────────────────────────────────────────────────────
now = datetime.now()
current_hour = now.hour
if 5 <= current_hour < 12:
    greeting = "Bom dia"
elif 12 <= current_hour < 18:
    greeting = "Boa tarde"
else:
    greeting = "Boa noite"

current_date = now.strftime("%Y-%m-%d")

def text_value(value):
    if isinstance(value, list):
        return "".join(str(part) for part in value)
    if value is None:
        return ""
    return str(value)

# ── Weather ──────────────────────────────────────────────────────────────
weather = "Clima indisponível"
try:
    with open(weather_cache_path) as f:
        data = json.load(f)
    val = text_value(data.get("temperatureText", ""))
    if val:
        weather = val
except Exception:
    pass

# ── Todos ────────────────────────────────────────────────────────────────
pending_tasks = 0
today_tasks = []
try:
    with open(todo_file_path) as f:
        data = json.load(f)
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                if not item.get("done"):
                    pending_tasks += 1
            elif isinstance(item, str) and item.strip():
                pending_tasks += 1
        today_str = str(date.today())
        for item in data:
            if isinstance(item, dict):
                title = item.get("title", item.get("text", ""))
                item_date = item.get("date", "")
                if item_date == today_str and title:
                    today_tasks.append(title)
            elif isinstance(item, str):
                today_tasks.append(item)
except Exception:
    pass

# ── Recent notes ─────────────────────────────────────────────────────────
recent_notes = []
def extract_titles(payload):
    titles = []
    if isinstance(payload, list):
        for item in payload:
            if isinstance(item, dict):
                title = item.get("title", item.get("text", item.get("name", "")))
            elif isinstance(item, str):
                title = item
            else:
                title = ""
            if title:
                titles.append(title)
    elif isinstance(payload, dict):
        title = payload.get("title", payload.get("text", payload.get("name", "")))
        if title:
            titles.append(title)
    return titles

try:
    if notes_file_path and os.path.exists(notes_file_path):
        with open(notes_file_path) as f:
            data = json.load(f)
        recent_notes = extract_titles(data)[:5]
except Exception:
    recent_notes = []

if not recent_notes:
    try:
        notes_files = []
        for fname in os.listdir(qs_state_dir):
            if fname.startswith(("notes", "quicknotes", "note")) and fname.endswith(".json"):
                notes_files.append(os.path.join(qs_state_dir, fname))
        for fp in notes_files:
            try:
                with open(fp) as f:
                    data = json.load(f)
                recent_notes.extend(extract_titles(data))
            except Exception:
                pass
        recent_notes = recent_notes[:5]
    except Exception:
        pass

# ── Pomodoro / focus sessions ────────────────────────────────────────────
pomodoro_sessions = 0

def read_session_count(path):
    try:
        with open(path) as f:
            data = json.load(f)
        if isinstance(data, list):
            return len(data)
        if isinstance(data, dict):
            for key in ("total_sessions", "completed_sessions", "sessions",
                        "pomodoro_count", "pomodoros", "count"):
                if key in data and isinstance(data[key], (int, float)):
                    return int(data[key])
    except Exception:
        pass
    return 0

productivity_metrics = os.path.join(qs_state_dir, "quickshell-productivity-metrics.json")
focus_metrics = os.path.join(qs_state_dir, "quickshell-focus-metrics.json")

pomodoro_sessions = read_session_count(productivity_metrics)
if pomodoro_sessions <= 0:
    pomodoro_sessions = read_session_count(focus_metrics)

# ── Build result ─────────────────────────────────────────────────────────
result = {
    "date": current_date,
    "greeting": greeting,
    "weather": weather,
    "pendingTasks": pending_tasks,
    "todayTasks": today_tasks,
    "recentNotes": recent_notes,
    "pomodoroSessions": pomodoro_sessions,
}
print(json.dumps(result, indent=2, ensure_ascii=False))

# ── Optional: notify-send ────────────────────────────────────────────────
if notify_enabled and shutil.which("notify-send"):
    summary = f"{greeting} — {current_date}"
    body = f"Tarefas pendentes: {pending_tasks}"
    if weather != "Clima indisponível":
        body += f" | Clima: {weather}"
    if pomodoro_sessions > 0:
        body += f" | Pomodoros: {pomodoro_sessions}"
    subprocess.run(
        ["notify-send", "--icon=dialog-information", "--expire-time=8000", summary, body],
        check=False,
    )
PYEOF
