#!/usr/bin/env bash
# random-wallpaper.sh - The Ultimate Anime/Geek Wallpaper & Theming Engine (v5.5 Pro)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/.local/share/wallpapers}"

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CACHE_DIR:-$CACHE_ROOT/wallpaper}"
LOG_FILE="${LOG_FILE:-$CACHE_DIR/wallpaper.log}"
HISTORY_FILE="${HISTORY_FILE:-$CACHE_DIR/history.log}"
FAVORITES_FILE="${FAVORITES_FILE:-$CACHE_DIR/favorites.log}"
FAVORITES_DIR="${FAVORITES_DIR:-$WALLPAPER_DIR/favorites}"
CURRENT_LINK="${CURRENT_LINK:-$CACHE_DIR/current-media}"
STYLIX_LINK="${STYLIX_LINK:-$CACHE_ROOT/stylix/current-wallpaper.jpg}"
MATUGEN_COLORS_FILE="${MATUGEN_COLORS_FILE:-$CACHE_ROOT/quickshell/matugen/colors.json}"
MPVPAPER_PID_FILE="$CACHE_DIR/mpvpaper.pid"
BACKEND_STATE_FILE="$CACHE_DIR/current-backend"
LOCK_FILE="$CACHE_DIR/apply.lock"
LOCK_TIMEOUT="${WALLPAPER_LOCK_TIMEOUT:-30}"

# Theming Defaults
MATUGEN_SCHEME_TYPE="${MATUGEN_SCHEME_TYPE:-scheme-vibrant}" # scheme-vibrant, scheme-tonal-spot, scheme-expressive, scheme-fidelity
ALLOW_NSFW="${ALLOW_NSFW:-true}"
ENABLE_VIDEO_WALLPAPERS="${ENABLE_VIDEO_WALLPAPERS:-false}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36}"

# ─── Self Test Contract ───────────────────────────────────────
if [[ "${1:-}" == "--self-test" ]]; then
    command -v jq >/dev/null 2>&1 || { echo "missing jq"; exit 1; }
    command -v shuf >/dev/null 2>&1 || { echo "missing shuf"; exit 1; }
    command -v flock >/dev/null 2>&1 || { echo "missing flock"; exit 1; }
    command -v find >/dev/null 2>&1 || { echo "missing find"; exit 1; }
    command -v curl >/dev/null 2>&1 || { echo "missing curl"; exit 1; }
    command -v file >/dev/null 2>&1 || { echo "missing file"; exit 1; }
    echo "ok"
    exit 0
fi

# Setup Dirs & Sources
mkdir -p "$WALLPAPER_DIR" "$CACHE_DIR" "$FAVORITES_DIR"
mkdir -p "$(dirname "$MATUGEN_COLORS_FILE")"
mkdir -p "$(dirname "$STYLIX_LINK")"
touch "$LOG_FILE" "$HISTORY_FILE" "$FAVORITES_FILE"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/lib/random_wallpaper_sources.sh"

# ─── Utility Functions ────────────────────────────────────────

is_on_ac() {
    # Returns 0 if AC connected or not a laptop
    local ac_online=""
    if [[ -r /sys/class/power_supply/AC/online ]]; then
        read -r ac_online < /sys/class/power_supply/AC/online || true
        [[ "$ac_online" == "1" ]] && return 0 || return 1
    fi
    return 0
}

get_time_mode() {
    local hour=""
    hour=$(date +%H)
    if (( hour >= 6 && hour < 18 )); then echo "light"; else echo "dark"; fi
}

extract_palette_hints() {
    local image="$1"

    python3 - "$image" <<'PY'
import collections
import subprocess
import sys

path = sys.argv[1]
try:
    raw = subprocess.check_output([
        "magick",
        path,
        "-auto-orient",
        "-resize", "64x64^>",
        "-gravity", "center",
        "-extent", "64x64",
        "-alpha", "off",
        "-depth", "8",
        "rgb:-",
    ])
except Exception as e:
    sys.exit(1)

pixels = [raw[i:i + 3] for i in range(0, len(raw), 3)]
if not pixels:
    raise SystemExit("no pixels decoded")

def luminance(rgb):
    r, g, b = [channel / 255.0 for channel in rgb]
    return (r * 0.299) + (g * 0.587) + (b * 0.114)

def saturation(rgb):
    r, g, b = [channel / 255.0 for channel in rgb]
    maximum = max(r, g, b)
    minimum = min(r, g, b)
    if maximum == 0:
        return 0.0
    return (maximum - minimum) / maximum

mean_luminance = sum(luminance(pixel) for pixel in pixels) / len(pixels)
mode = "light" if mean_luminance >= 0.60 else "dark"

bins = collections.Counter()
for pixel in pixels:
    bins[tuple(((channel // 16) * 16) + 8 for channel in pixel)] += 1

ranked = []
for rgb, count in bins.items():
    lum = luminance(rgb)
    sat = saturation(rgb)
    mid_bias = max(0.0, 1.0 - abs(lum - 0.55) / 0.55)
    score = count * (0.10 + (sat ** 1.8) * 2.5) * (0.35 + mid_bias)
    if sat < 0.08:
        score *= 0.08
    if lum > 0.93 or lum < 0.08:
        score *= 0.05
    ranked.append((score, count, sat, lum, rgb))

ranked.sort(reverse=True)
vivid = [
    item for item in ranked
    if item[2] >= 0.18 and 0.12 <= item[3] <= 0.88
][:12]

if vivid:
    total = sum(item[0] for item in vivid)
    red = round(sum(item[4][0] * item[0] for item in vivid) / total)
    green = round(sum(item[4][1] * item[0] for item in vivid) / total)
    blue = round(sum(item[4][2] * item[0] for item in vivid) / total)
    source = (red, green, blue)
else:
    source = ranked[0][4] if ranked else bins.most_common(1)[0][0]

print(mode)
print(f"#{source[0]:02X}{source[1]:02X}{source[2]:02X}")
print(f"{mean_luminance:.5f}")
PY
}

is_video_media() {
    local file="${1,,}"
    [[ "$file" =~ \.(mp4|webm|mkv|mov|gif)$ ]]
}

current_backend() {
    [[ -f "$BACKEND_STATE_FILE" ]] && cat "$BACKEND_STATE_FILE" || true
}

set_backend_state() {
    printf '%s\n' "$1" > "$BACKEND_STATE_FILE"
}

extract_video_preview() {
    local wallpaper="$1"
    local preview="${wallpaper}.preview.jpg"

    if ! command -v ffmpeg >/dev/null 2>&1; then
        log "Error: ffmpeg is required to sample animated wallpapers."
        return 1
    fi

    if ffmpeg -y -loglevel error -i "$wallpaper" -frames:v 1 "$preview" >/dev/null 2>&1; then
        printf '%s\n' "$preview"
        return 0
    fi

    log "Error: could not extract preview image from video wallpaper: $wallpaper"
    return 1
}

wait_for_process_exit() {
    local pid="$1"
    local attempts="${2:-30}"

    while (( attempts > 0 )) && kill -0 "$pid" 2>/dev/null; do
        sleep 0.1
        attempts=$((attempts - 1))
    done

    ! kill -0 "$pid" 2>/dev/null
}

resolve_quickshell_bin() {
    local user_name=""
    user_name="$(id -un 2>/dev/null || true)"

    for candidate in \
        "${QUICKSHELL_BIN:-}" \
        "$HOME/.nix-profile/bin/quickshell" \
        "/etc/profiles/per-user/${user_name}/bin/quickshell" \
        "/nix/var/nix/profiles/default/bin/quickshell" \
        "/run/current-system/sw/bin/quickshell"
    do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    command -v quickshell 2>/dev/null || true
}

notify_quickshell_colors_changed() {
    local quickshell_bin=""
    quickshell_bin="$(resolve_quickshell_bin)"
    [[ -n "$quickshell_bin" ]] || return 0

    "$quickshell_bin" ipc --any-display call ipcHandler reloadColors >/dev/null 2>&1 || true
}

update_hyprland_borders() {
    local accent_hex="${1:-}"
    [[ -n "$accent_hex" ]] || return 0

    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        local raw_hex="${accent_hex#\#}"
        hyprctl keyword general:col.active_border "rgba(${raw_hex}ee) rgba(${raw_hex}88) 45deg" >/dev/null 2>&1 || true
    fi
}

stop_mpvpaper() {
    local pid=""
    local child_pid=""
    local -a pids=()

    if [[ -f "$MPVPAPER_PID_FILE" ]]; then
        pid=$(<"$MPVPAPER_PID_FILE")
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            pids+=("$pid")
        fi
    fi

    while IFS= read -r pid; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        if [[ " ${pids[*]} " != *" $pid "* ]]; then
            pids+=("$pid")
        fi
    done < <(pgrep -x mpvpaper 2>/dev/null || true)

    # Also stop child processes spawned by mpvpaper (mpv decoder/renderers).
    for pid in "${pids[@]}"; do
        while IFS= read -r child_pid; do
            [[ "$child_pid" =~ ^[0-9]+$ ]] || continue
            if [[ " ${pids[*]} " != *" $child_pid "* ]]; then
                pids+=("$child_pid")
            fi
        done < <(pgrep -P "$pid" 2>/dev/null || true)
    done

    rm -f "$MPVPAPER_PID_FILE"

    if (( ${#pids[@]} == 0 )); then
        return 0
    fi

    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping mpvpaper PID $pid"
            kill "$pid" 2>/dev/null || true
        fi
    done

    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null && ! wait_for_process_exit "$pid" 30; then
            log "mpvpaper PID $pid did not exit cleanly; forcing termination."
            kill -KILL "$pid" 2>/dev/null || true
            wait_for_process_exit "$pid" 10 || true
        fi
    done
}

ensure_awww_daemon() {
    local daemon_pid=""
    local attempts=40

    if awww query >/dev/null 2>&1; then
        return 0
    fi

    log "Starting awww-daemon..."
    nohup awww-daemon >/dev/null 2>&1 &
    daemon_pid=$!
    disown || true

    sleep 0.2
    while (( attempts > 0 )); do
        if awww query >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        attempts=$((attempts - 1))
    done

    log "Error: awww-daemon did not become ready."
    if [[ -n "$daemon_pid" ]] && kill -0 "$daemon_pid" 2>/dev/null; then
        kill "$daemon_pid" 2>/dev/null || true
    fi
    return 1
}

restart_awww_daemon() {
    log "Restarting awww-daemon..."
    awww kill >/dev/null 2>&1 || true
    sleep 0.2
    ensure_awww_daemon
}

verify_awww_wallpaper() {
    local wallpaper="$1"
    local state=""

    state=$(awww query 2>/dev/null || true)
    [[ "$state" == *"$wallpaper"* ]]
}

# ─── Dynamic Transitions (awww) ───────────────────────────────

build_transition_args() {
    local width height ratio refresh
    read -r width height ratio refresh <<< "$(detect_screen_specs)"
    local fps="${refresh:-60}"
    if (( fps < 30 || fps > 360 )); then fps=60; fi

    local idx=$(( RANDOM % 14 ))
    local base="--transition-fps $fps --transition-bezier .54,0,.34,0.99"
    case "$idx" in
        0)  echo "--transition-type simple  --transition-duration 1.2 $base" ;;
        1)  echo "--transition-type fade    --transition-duration 1.0 $base" ;;
        2)  echo "--transition-type left    --transition-duration 0.9 $base" ;;
        3)  echo "--transition-type right   --transition-duration 0.9 $base" ;;
        4)  echo "--transition-type top     --transition-duration 0.9 $base" ;;
        5)  echo "--transition-type bottom  --transition-duration 0.9 $base" ;;
        6)  echo "--transition-type center  --transition-duration 1.1 $base" ;;
        7)  echo "--transition-type outer   --transition-duration 1.1 $base" ;;
        8)  echo "--transition-type wipe    --transition-angle 30  --transition-duration 0.9 $base" ;;
        9)  echo "--transition-type wipe    --transition-angle 135 --transition-duration 0.9 $base" ;;
        10) echo "--transition-type wave    --transition-angle 45  --transition-wave 80,40 --transition-duration 1.3 $base" ;;
        11) echo "--transition-type grow    --transition-pos 0.5,0.5 --transition-duration 1.0 $base" ;;
        12) echo "--transition-type grow    --transition-pos 0.0,1.0 --transition-duration 1.0 $base" ;;
        13) echo "--transition-type grow    --transition-pos 1.0,0.0 --transition-duration 1.0 $base" ;;
    esac
}

apply_static_wallpaper() {
    local wallpaper="$1"
    local -a trans_args

    stop_mpvpaper

    if ! ensure_awww_daemon; then
        return 1
    fi

    read -ra trans_args <<< "$(build_transition_args)"

    if ! awww img "$wallpaper" "${trans_args[@]}" >/dev/null 2>&1; then
        log "awww failed to apply wallpaper on first attempt."
        if ! restart_awww_daemon; then
            return 1
        fi
        if ! awww img "$wallpaper" --transition-type none >/dev/null 2>&1; then
            log "Error: failed to apply wallpaper with awww: $wallpaper"
            return 1
        fi
    fi

    if ! verify_awww_wallpaper "$wallpaper"; then
        log "awww reported unexpected state after apply; restarting daemon and retrying."
        if ! restart_awww_daemon; then
            return 1
        fi
        if ! awww img "$wallpaper" --transition-type none >/dev/null 2>&1; then
            log "Error: failed to re-apply wallpaper with awww after daemon restart: $wallpaper"
            return 1
        fi
        if ! verify_awww_wallpaper "$wallpaper"; then
            log "Error: awww still did not report the expected wallpaper: $wallpaper"
            return 1
        fi
    fi

    set_backend_state "static"
}

apply_video_wallpaper() {
    local wallpaper="$1"
    local mpvpaper_pid=""

    stop_mpvpaper

    log "Starting mpvpaper..."
    nohup mpvpaper -o "--no-audio --loop-playlist=inf --panscan=1.0 --vf=lavfi=[fade=t=in:st=0:d=1]" '*' "$wallpaper" >/dev/null 2>&1 &
    mpvpaper_pid=$!
    disown || true
    printf '%s\n' "$mpvpaper_pid" > "$MPVPAPER_PID_FILE"

    sleep 0.2
    if ! kill -0 "$mpvpaper_pid" 2>/dev/null; then
        rm -f "$MPVPAPER_PID_FILE"
        log "Error: mpvpaper exited immediately for $wallpaper"
        return 1
    fi

    set_backend_state "video"
}

pick_static_fallback() {
    local preferred="${1:-}"
    local stylix_current=""
    local media_current=""
    local default_wallpaper=""
    local candidate=""

    stylix_current="$(readlink -f "$STYLIX_LINK" 2>/dev/null || true)"
    media_current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
    default_wallpaper="$(get_default_wallpaper)"

    for candidate in "$preferred" "$stylix_current" "$media_current" "$default_wallpaper"; do
        [[ -n "$candidate" ]] || continue
        [[ -f "$candidate" ]] || continue
        if is_video_media "$candidate"; then
            continue
        fi
        printf '%s\n' "$candidate"
        return 0
    done

    return 1
}

with_wallpaper_lock() {
    local lock_fd=""
    local status=0

    exec {lock_fd}>"$LOCK_FILE"
    if ! flock -w "$LOCK_TIMEOUT" "$lock_fd"; then
        log "Error: timed out waiting for wallpaper lock after ${LOCK_TIMEOUT}s."
        exec {lock_fd}>&-
        return 1
    fi

    "$@" || status=$?

    flock -u "$lock_fd" || true
    exec {lock_fd}>&-
    return "$status"
}

# ─── Application Engine ───────────────────────────────────────

apply_wallpaper() {
    local wallpaper="$1"
    local preview=""
    local fallback_static=""
    [[ -f "$wallpaper" ]] || return 1

    local base_name
    base_name="$(basename "$wallpaper")"
    log "Applying: $base_name"

    # 1. Video / Battery Check
    if is_video_media "$wallpaper"; then
        if [[ "$ENABLE_VIDEO_WALLPAPERS" != "true" ]]; then
            log "Animated wallpapers are disabled; using static preview."
            if ! preview="$(extract_video_preview "$wallpaper")"; then
                return 1
            fi
            wallpaper="$preview"
        elif ! is_on_ac; then
            log "On Battery: Converting video wallpaper to static for power saving."
            if ! preview="$(extract_video_preview "$wallpaper")"; then
                return 1
            fi
            wallpaper="$preview"
        else
            preview="$(extract_video_preview "$wallpaper" 2>/dev/null)" || true
        fi
    fi

    # 2. Execution (awww or mpvpaper)
    if is_video_media "$wallpaper" && is_on_ac && [[ "$ENABLE_VIDEO_WALLPAPERS" == "true" ]]; then
        if ! apply_video_wallpaper "$wallpaper"; then
            log "Video wallpaper backend failed; applying static fallback."
            if ! fallback_static="$(pick_static_fallback "${preview:-}")"; then
                log "Error: no valid static fallback wallpaper found."
                return 1
            fi
            if ! apply_static_wallpaper "$fallback_static"; then
                log "Error: failed to apply static fallback wallpaper: $fallback_static"
                return 1
            fi
            wallpaper="$fallback_static"
            preview="$fallback_static"
        fi
    else
        if ! apply_static_wallpaper "$wallpaper"; then
            return 1
        fi
    fi

    # 3. Update links and history (Foreground)
    ln -sf "$wallpaper" "$CURRENT_LINK"
    ln -sf "${preview:-$wallpaper}" "$STYLIX_LINK"
    save_to_history "$wallpaper"

    # 4. Matugen & Theming (Background Async)
    (
        local sample="${preview:-$wallpaper}"
        if [[ -n "$sample" && -f "$sample" ]] && command -v matugen >/dev/null 2>&1; then
            local tmp_colors="${MATUGEN_COLORS_FILE}.tmp"
            local palette_mode=""
            local palette_source=""
            local analysis=""
            local dominant_color=""

            if command -v python3 >/dev/null 2>&1 && command -v magick >/dev/null 2>&1; then
                if analysis=$(extract_palette_hints "$sample" 2>/dev/null); then
                    palette_mode=$(printf '%s\n' "$analysis" | sed -n '1p')
                    palette_source=$(printf '%s\n' "$analysis" | sed -n '2p')
                fi
            fi

            if [[ -z "$palette_mode" ]]; then
                palette_mode=$(get_time_mode)
            fi

            if [[ -z "$palette_source" ]] && command -v magick >/dev/null 2>&1; then
                dominant_color=$(magick "$sample" -colors 1 -unique-colors txt:- 2>/dev/null | grep -oE '#[A-Fa-f0-9]{6}' | head -n 1 || true)
                if [[ -n "$dominant_color" ]]; then
                    palette_source="$dominant_color"
                fi
            fi

            if [[ -n "$palette_source" ]]; then
                if matugen color hex "$palette_source" --mode "$palette_mode" --type "$MATUGEN_SCHEME_TYPE" --json hex --quiet > "$tmp_colors" 2>/dev/null && [[ -s "$tmp_colors" ]]; then
                    mv -f "$tmp_colors" "$MATUGEN_COLORS_FILE"
                    notify_quickshell_colors_changed
                    update_hyprland_borders "$palette_source"
                    log "Theme updated: mode=$palette_mode source=$palette_source type=$MATUGEN_SCHEME_TYPE"
                fi
            fi
        fi

        # Notification
        if command -v notify-send >/dev/null 2>&1; then
            local fav_badge=""
            if is_favorite "$wallpaper"; then fav_badge=" [★ Favorite]"; fi
            notify-send -a "Wallpaper Engine" -i "${preview:-$wallpaper}" "Wallpaper Engine" "Novo wallpaper aplicado: $base_name$fav_badge"
        fi

        rotate_log
    ) & disown
}

# ─── Smart Picker Logic ───────────────────────────────────────

pick_smart_wallpaper() {
    local source_mode="${1:-auto}"
    local query_term="${2:-}"
    local topic_term="${3:-}"

    local wallpaper=""
    local max_attempts=4
    local attempt=0

    # 1. Explicit query or topic
    if [[ -n "$query_term" || -n "$topic_term" ]]; then
        wallpaper=$(fetch_wallhaven "$query_term" "$topic_term" || fetch_konachan "$query_term" || fetch_safebooru "$query_term" || get_local_random "$topic_term")
        if [[ -n "$wallpaper" ]]; then
            printf '%s\n' "$wallpaper"
            return 0
        fi
    fi

    # 2. Specific source mode
    case "$source_mode" in
        fav|favorite|favorites)
            wallpaper=$(get_random_favorite || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        local)
            wallpaper=$(get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        wallhaven)
            wallpaper=$(fetch_wallhaven "" "$topic_term" || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        yande)
            wallpaper=$(fetch_yande "" || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        nasa)
            wallpaper=$(fetch_nasa_apod || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        konachan)
            wallpaper=$(fetch_konachan || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        bing)
            wallpaper=$(fetch_bing_daily || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
        safebooru)
            wallpaper=$(fetch_safebooru || get_local_random)
            printf '%s\n' "$wallpaper"
            return 0
            ;;
    esac

    # 3. Auto Balanced Engine (25% Local, 75% Multi-Provider Online)
    while (( attempt < max_attempts )); do
        local roll=$(( RANDOM % 100 ))

        if (( roll < 25 )); then
            # 25% chance local
            wallpaper=$(get_local_random)
        elif (( roll < 45 )); then
            # 20% chance Wallhaven (Purity 011: Sketchy + NSFW)
            wallpaper=$(fetch_wallhaven "" "$topic_term" || fetch_yande || get_local_random)
        elif (( roll < 65 )); then
            # 20% chance Yande.re (Anime HQ / Art)
            wallpaper=$(fetch_yande "" || fetch_konachan || get_local_random)
        elif (( roll < 80 )); then
            # 15% chance Konachan (konachan.com / konachan.net)
            wallpaper=$(fetch_konachan || fetch_yande || get_local_random)
        elif (( roll < 90 )); then
            # 10% chance Bing Daily UHD (Landscapes/Nature)
            wallpaper=$(fetch_bing_daily || fetch_wallhaven "" "$topic_term" || get_local_random)
        elif (( roll < 96 )); then
            # 6% chance NASA APOD (Astronomy 4K)
            wallpaper=$(fetch_nasa_apod || fetch_bing_daily || get_local_random)
        else
            # 4% chance Safebooru / Reddit
            wallpaper=$(fetch_safebooru || fetch_reddit || get_local_random)
        fi

        # Check anti-repetition (avoid top 15 recent history)
        if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
            if ! head -n 15 "$HISTORY_FILE" 2>/dev/null | grep -qxF "$wallpaper"; then
                break
            fi
        fi
        attempt=$((attempt + 1))
    done

    # Final Fallbacks
    if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
        wallpaper=$(get_local_random)
    fi

    if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
        wallpaper=$(get_default_wallpaper)
    fi

    printf '%s\n' "$wallpaper"
}

# ─── Handler Functions for Locked Operations ──────────────────

handle_next() {
    local wp
    wp="$(pick_smart_wallpaper 'auto')"
    if [[ -n "$wp" && -f "$wp" ]]; then
        apply_wallpaper "$wp"
    else
        log "Error: could not find any wallpaper candidate."
        return 1
    fi
}

handle_query() {
    local query="$1"
    local wp
    wp="$(pick_smart_wallpaper 'auto' "$query" '')"
    if [[ -n "$wp" && -f "$wp" ]]; then
        apply_wallpaper "$wp"
    else
        log "Error: no wallpaper found for query: $query"
        return 1
    fi
}

handle_topic() {
    local topic="$1"
    local wp
    wp="$(pick_smart_wallpaper 'auto' '' "$topic")"
    if [[ -n "$wp" && -f "$wp" ]]; then
        apply_wallpaper "$wp"
    else
        log "Error: no wallpaper found for topic: $topic"
        return 1
    fi
}

handle_source() {
    local src="$1"
    local wp
    wp="$(pick_smart_wallpaper "$src" '' '')"
    if [[ -n "$wp" && -f "$wp" ]]; then
        apply_wallpaper "$wp"
    else
        log "Error: no wallpaper found from source: $src"
        return 1
    fi
}

handle_fav() {
    local wp
    wp="$(pick_smart_wallpaper 'fav')"
    if [[ -z "$wp" || ! -f "$wp" ]]; then
        log "No favorites found. Picking random..."
        wp="$(pick_smart_wallpaper 'auto')"
    fi
    if [[ -n "$wp" && -f "$wp" ]]; then
        apply_wallpaper "$wp"
    else
        log "Error: no wallpaper available."
        return 1
    fi
}

handle_trash() {
    local current=""
    current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
    if [[ -n "$current" && -f "$current" ]]; then
        local base_name
        base_name="$(basename "$current")"
        trash_wallpaper "$current"
        command -v notify-send >/dev/null 2>&1 && notify-send -a "Wallpaper Engine" "Wallpaper Engine" "🗑️ Wallpaper descartado: $base_name"
        handle_next
    else
        log "Error: no active wallpaper found to delete."
        return 1
    fi
}

# ─── IPC & Help ───────────────────────────────────────────────

show_help() {
    cat <<'EOF'
random-wallpaper.sh - Pro Wallpaper & Theming Engine

USAGE:
  random-wallpaper.sh [COMMAND] [OPTIONS]

COMMANDS:
  --next, -n                Pick a new random wallpaper (multi-source balanced)
  --prev, -p                Go back to previous wallpaper in history
  --fav, --favorites        Pick a random wallpaper strictly from Favorites
  --save                    Save current wallpaper to Favorites
  --trash, --delete         Trash/Delete current wallpaper and pick next immediately
  --file <PATH>             Apply a specific wallpaper file
  --restore                 Restore last wallpaper on login/boot
  --query, -q <SEARCH>      Search and apply wallpaper matching keywords
  --topic, -t <TOPIC>       Pick wallpaper by curated topic
  --source, -s <SOURCE>     Force source: local | wallhaven | yande | konachan | nasa | bing | safebooru | fav
  --copy, --copy-path       Copy current wallpaper path to clipboard
  --copy-image              Copy current wallpaper image data to clipboard
  --open                    Open current wallpaper in default viewer
  --clean-cache [MAX_MB]    Clean broken/old downloads (default: 2048MB)
  --info                    Show current wallpaper state, colors, resolution, and backend
  --help, -h                Show this help message

TOPICS:
  anime, cyberpunk, landscape, space, minimal, pixelart

EXAMPLES:
  random-wallpaper.sh --next
  random-wallpaper.sh --query "cyberpunk city"
  random-wallpaper.sh --source yande
  random-wallpaper.sh --source nasa
  random-wallpaper.sh --topic anime
  random-wallpaper.sh --fav
  random-wallpaper.sh --trash
  random-wallpaper.sh --clean-cache 1024
EOF
}

# ─── Main Controller ──────────────────────────────────────────

main() {
    local cmd="${1:---next}"
    shift || true

    case "$cmd" in
        --help|-h)
            show_help
            ;;

        --file)
            local explicit_wallpaper="${1:-}"
            if [[ -z "$explicit_wallpaper" || ! -f "$explicit_wallpaper" ]]; then
                log "Error: --file requires a valid wallpaper file path."
                return 1
            fi
            with_wallpaper_lock apply_wallpaper "$explicit_wallpaper"
            ;;

        --restore)
            local boot_wallpaper=""
            boot_wallpaper="$(get_boot_wallpaper)"
            if [[ -z "$boot_wallpaper" || ! -f "$boot_wallpaper" ]]; then
                boot_wallpaper="$(get_local_random)"
            fi
            if [[ -z "$boot_wallpaper" || ! -f "$boot_wallpaper" ]]; then
                log "Error: could not resolve any wallpaper to restore."
                return 1
            fi
            with_wallpaper_lock apply_wallpaper "$boot_wallpaper"
            ;;

        --save|--favorite)
            local current=""
            current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
            if [[ -n "$current" && -f "$current" ]]; then
                save_to_favorites "$current"
                command -v notify-send >/dev/null 2>&1 && notify-send -a "Wallpaper Engine" -i "$current" "Wallpaper Engine" "★ Salvo nos Favoritos: $(basename "$current")"
            else
                log "Error: no current wallpaper to save."
            fi
            ;;

        --trash|--delete)
            with_wallpaper_lock handle_trash
            ;;

        --prev|-p)
            local prev=""
            prev=$(sed -n '2p' "$HISTORY_FILE" 2>/dev/null || true)
            if [[ -n "$prev" && -f "$prev" ]]; then
                if with_wallpaper_lock apply_wallpaper "$prev"; then
                    sed -i '1,2d' "$HISTORY_FILE"
                fi
            else
                log "No previous wallpaper found in history."
            fi
            ;;

        --fav|--from-favorites)
            with_wallpaper_lock handle_fav
            ;;

        --query|-q)
            local query="${1:-}"
            if [[ -z "$query" ]]; then
                log "Error: --query requires a search term."
                return 1
            fi
            with_wallpaper_lock handle_query "$query"
            ;;

        --topic|-t)
            local topic="${1:-anime}"
            with_wallpaper_lock handle_topic "$topic"
            ;;

        --source|-s)
            local src="${1:-auto}"
            with_wallpaper_lock handle_source "$src"
            ;;

        --copy|--copy-path)
            local current=""
            current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
            if [[ -n "$current" && -f "$current" ]]; then
                if command -v wl-copy >/dev/null 2>&1; then
                    printf '%s' "$current" | wl-copy
                    command -v notify-send >/dev/null 2>&1 && notify-send -a "Wallpaper Engine" "Wallpaper Engine" "📋 Caminho copiado: $current"
                    echo "$current"
                fi
            fi
            ;;

        --copy-image)
            local current=""
            current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
            if [[ -n "$current" && -f "$current" ]]; then
                if command -v wl-copy >/dev/null 2>&1; then
                    wl-copy -t image/png < "$current" 2>/dev/null || wl-copy < "$current"
                    command -v notify-send >/dev/null 2>&1 && notify-send -a "Wallpaper Engine" "Wallpaper Engine" "🖼️ Imagem copiada para o clipboard!"
                fi
            fi
            ;;

        --open)
            local current=""
            current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
            if [[ -n "$current" && -f "$current" ]]; then
                command -v xdg-open >/dev/null 2>&1 && xdg-open "$current" &
            fi
            ;;

        --clean-cache)
            local max_mb="${1:-2048}"
            with_wallpaper_lock clean_wallpaper_cache "$max_mb"
            ;;

        --info)
            local current=""
            current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
            local is_fav="No"
            if is_favorite "$current"; then is_fav="Yes (★)"; fi

            local width height ratio refresh
            read -r width height ratio refresh <<< "$(detect_screen_specs)"

            echo "=== Wallpaper Engine (v5.5 Pro) ==="
            echo "Current Wallpaper : ${current:-None}"
            echo "Is Favorite       : $is_fav"
            echo "Backend           : $(current_backend)"
            echo "Display Specs     : ${width}x${height} (${ratio}) @ ${refresh}Hz"
            echo "Purity / Rating   : ${WALLHAVEN_PURITY:-011} (Sketchy + NSFW Enabled)"
            echo "Categories        : ${WALLHAVEN_CATEGORIES:-111} (General + Anime + People)"
            echo "Matugen Scheme    : $MATUGEN_SCHEME_TYPE"
            echo "Time / Light Mode : $(get_time_mode)"
            echo "Power State       : $(is_on_ac && echo 'AC' || echo 'Battery')"
            echo "Video Wallpapers  : $ENABLE_VIDEO_WALLPAPERS"
            echo "History Entries   : $(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)"
            echo "Favorites Total   : $(wc -l < "$FAVORITES_FILE" 2>/dev/null || echo 0)"
            ;;

        --next|"-n"|"")
            with_wallpaper_lock handle_next
            ;;

        *)
            log "Error: unknown command '$cmd'"
            show_help
            return 1
            ;;
    esac
}

main "$@"
