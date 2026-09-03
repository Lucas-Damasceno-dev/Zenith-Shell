#!/usr/bin/env bash
# lib/random_wallpaper_sources.sh - Modern Multi-Source Engine & Atomic Cache Helper

if [[ "${BASH_SOURCE[0]}" == "$0" && "${1:-}" == "--self-test" ]]; then
    command -v jq >/dev/null 2>&1 || { echo "missing jq"; exit 1; }
    command -v curl >/dev/null 2>&1 || { echo "missing curl"; exit 1; }
    command -v shuf >/dev/null 2>&1 || { echo "missing shuf"; exit 1; }
    command -v file >/dev/null 2>&1 || { echo "missing file"; exit 1; }
    echo "ok"
    exit 0
fi

# ─── Environment & Paths ───────────────────────────────────────
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/.local/share/wallpapers}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="${CACHE_DIR:-$CACHE_ROOT/wallpaper}"
LOG_FILE="${LOG_FILE:-$CACHE_DIR/wallpaper.log}"
HISTORY_FILE="${HISTORY_FILE:-$CACHE_DIR/history.log}"
FAVORITES_FILE="${FAVORITES_FILE:-$CACHE_DIR/favorites.log}"
FAVORITES_DIR="${FAVORITES_DIR:-$WALLPAPER_DIR/favorites}"
CURRENT_LINK="${CURRENT_LINK:-$CACHE_DIR/current-media}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36}"
ALLOW_NSFW="${ALLOW_NSFW:-true}"
WALLHAVEN_PURITY="${WALLHAVEN_PURITY:-011}"
WALLHAVEN_CATEGORIES="${WALLHAVEN_CATEGORIES:-111}"
WALLHAVEN_API_KEY="${WALLHAVEN_API_KEY:-}"

mkdir -p "$WALLPAPER_DIR" "$CACHE_DIR" "$FAVORITES_DIR"
touch "$LOG_FILE" "$HISTORY_FILE" "$FAVORITES_FILE"

# ─── Logging & Rotation ────────────────────────────────────────

log() {
    local msg="$*"
    printf '[%s] %s\n' "$(date '+%F %T')" "$msg" >> "$LOG_FILE"
    printf '%s\n' "$msg" >&2
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]] && (( $(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) > 600 )); then
        tail -n 300 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv -f "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

# ─── Display & Monitor Detection ───────────────────────────────

detect_screen_specs() {
    # Returns: WIDTH HEIGHT RATIO REFRESH_RATE
    local width=1920
    local height=1080
    local refresh=60
    local ratio="16x9"

    if command -v hyprctl >/dev/null 2>&1; then
        local monitors_json=""
        monitors_json=$(hyprctl monitors -j 2>/dev/null || true)
        if [[ -n "$monitors_json" ]] && command -v jq >/dev/null 2>&1; then
            local detected_w detected_h detected_hz
            detected_w=$(printf '%s' "$monitors_json" | jq -r '[.[].width] | max // 1920' 2>/dev/null || echo "1920")
            detected_h=$(printf '%s' "$monitors_json" | jq -r '[.[].height] | max // 1080' 2>/dev/null || echo "1080")
            detected_hz=$(printf '%s' "$monitors_json" | jq -r '[.[].refreshRate | floor] | max // 60' 2>/dev/null || echo "60")

            if [[ "$detected_w" =~ ^[0-9]+$ ]] && (( detected_w > 0 )); then width="$detected_w"; fi
            if [[ "$detected_h" =~ ^[0-9]+$ ]] && (( detected_h > 0 )); then height="$detected_h"; fi
            if [[ "$detected_hz" =~ ^[0-9]+$ ]] && (( detected_hz > 0 )); then refresh="$detected_hz"; fi

            # Estimate aspect ratio
            if (( width * 9 == height * 16 )); then
                ratio="16x9"
            elif (( width * 10 == height * 16 )); then
                ratio="16x10"
            elif (( width * 9 == height * 21 )) || (( width * 10 == height * 24 )); then
                ratio="21x9"
            elif (( width * 9 == height * 32 )); then
                ratio="32x9"
            fi
        fi
    fi

    printf '%d %d %s %d\n' "$width" "$height" "$ratio" "$refresh"
}

# ─── Validation & Atomic Storage ───────────────────────────────

validate_and_save_image() {
    local tmp_file="$1"
    local dest_file="$2"

    if [[ ! -s "$tmp_file" ]]; then
        rm -f "$tmp_file"
        return 1
    fi

    # Check minimum file size (at least 15KB)
    local size
    size=$(stat -c%s "$tmp_file" 2>/dev/null || echo "0")
    if (( size < 15360 )); then
        rm -f "$tmp_file"
        return 1
    fi

    # Validate MIME type (must be image or video)
    local mime_type=""
    if command -v file >/dev/null 2>&1; then
        mime_type=$(file -b --mime-type "$tmp_file" 2>/dev/null || true)
        if [[ ! "$mime_type" =~ ^(image/|video/) ]]; then
            log "Validation failed: invalid mime type ($mime_type) for $tmp_file"
            rm -f "$tmp_file"
            return 1
        fi
    fi

    # Extra check with ImageMagick if available for images
    if [[ "$mime_type" =~ ^image/ ]] && command -v magick >/dev/null 2>&1; then
        if ! magick identify -ping "$tmp_file" >/dev/null 2>&1; then
            log "Validation failed: ImageMagick ping error for $tmp_file"
            rm -f "$tmp_file"
            return 1
        fi
    fi

    mv -f "$tmp_file" "$dest_file"
    return 0
}

# ─── History & Favorites Management ────────────────────────────

save_to_history() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    { echo "$path"; grep -vF "$path" "$HISTORY_FILE" 2>/dev/null || true; } | head -n 50 > "${HISTORY_FILE}.tmp"
    mv -f "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
}

remove_from_history() {
    local path="$1"
    [[ -n "$path" && -f "$HISTORY_FILE" ]] || return 0
    grep -vF "$path" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null || true
    mv -f "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
}

save_to_favorites() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    mkdir -p "$FAVORITES_DIR"

    # Add to favorites log (deduped)
    { echo "$path"; grep -vF "$path" "$FAVORITES_FILE" 2>/dev/null || true; } > "${FAVORITES_FILE}.tmp"
    mv -f "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE"

    # Symlink to favorites folder for easy browser access
    local base_name
    base_name="$(basename "$path")"
    ln -sf "$path" "$FAVORITES_DIR/$base_name"
    log "Favorites: Saved $base_name"
}

remove_from_favorites() {
    local path="$1"
    [[ -n "$path" ]] || return 0
    local base_name
    base_name="$(basename "$path")"
    rm -f "$FAVORITES_DIR/$base_name"
    if [[ -f "$FAVORITES_FILE" ]]; then
        grep -vF "$path" "$FAVORITES_FILE" > "${FAVORITES_FILE}.tmp" 2>/dev/null || true
        mv -f "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE"
    fi
    log "Favorites: Removed $base_name"
}

is_favorite() {
    local path="$1"
    [[ -f "$path" && -f "$FAVORITES_FILE" ]] && grep -qxF "$path" "$FAVORITES_FILE"
}

get_random_favorite() {
    local candidates=()
    local item=""

    # Read from favorites.log
    if [[ -f "$FAVORITES_FILE" ]]; then
        while IFS= read -r item; do
            [[ -n "$item" && -f "$item" ]] && candidates+=("$item")
        done < "$FAVORITES_FILE"
    fi

    # Also search directly in favorites directory
    if [[ -d "$FAVORITES_DIR" ]]; then
        while IFS= read -r item; do
            [[ -n "$item" && -f "$item" ]] && candidates+=("$item")
        done < <(find "$FAVORITES_DIR" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' -o -name '*.gif' -o -name '*.mp4' \) 2>/dev/null || true)
    fi

    if (( ${#candidates[@]} == 0 )); then
        return 1
    fi

    # Return a unique shuffled item
    printf '%s\n' "${candidates[@]}" | sort -u | shuf -n1
}

trash_wallpaper() {
    local path="$1"
    [[ -f "$path" ]] || return 1

    local base_name
    base_name="$(basename "$path")"
    remove_from_history "$path"
    remove_from_favorites "$path"

    # Remove preview if existed
    rm -f "${path}.preview.jpg"

    # Move to trash if available, or delete
    local trash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
    if [[ -d "$trash_dir" ]]; then
        mv -f "$path" "$trash_dir/"
        log "Trashed to $trash_dir: $base_name"
    else
        rm -f "$path"
        log "Deleted: $base_name"
    fi
}

clean_wallpaper_cache() {
    local max_mb="${1:-2048}" # default 2GB
    log "Cleaning wallpaper cache (max: ${max_mb}MB)..."

    # 1. Clean broken temporary files and zero-byte files
    find "$WALLPAPER_DIR" "$CACHE_DIR" -type f \( -name '*.tmp' -o -size 0 \) -delete 2>/dev/null || true

    # 2. Check total directory size in MB
    local total_kb total_mb
    total_kb=$(du -sk "$WALLPAPER_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    total_mb=$(( total_kb / 1024 ))

    if (( total_mb > max_mb )); then
        log "Cache size (${total_mb}MB) exceeds limit (${max_mb}MB). Pruning oldest non-favorite files..."
        local file=""
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue
            # Never delete favorites!
            if is_favorite "$file"; then
                continue
            fi
            rm -f "$file" "${file}.preview.jpg"
            total_kb=$(du -sk "$WALLPAPER_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
            total_mb=$(( total_kb / 1024 ))
            if (( total_mb <= max_mb )); then
                break
            fi
        done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | awk '{print $2}')
    fi

    rotate_log
    log "Cache cleaning complete. Current size: ${total_mb}MB."
}

# ─── Multi-Source Providers ────────────────────────────────────

fetch_wallhaven() {
    local query_arg="${1:-}"
    local topic_arg="${2:-}"
    local purity="${WALLHAVEN_PURITY:-011}" # 011 = Sketchy + NSFW, 111 = All
    local categories="${WALLHAVEN_CATEGORIES:-111}" # 111 = General + Anime + People

    # Resolution & Specs
    local width height ratio refresh
    read -r width height ratio refresh <<< "$(detect_screen_specs)"

    # Topic / Query Selection
    local query="$query_arg"
    if [[ -z "$query" ]]; then
        case "$topic_arg" in
            anime)
                local anime_queries=("anime+aesthetic" "anime+scenery" "moescape" "studio+ghibli" "makoto+shinkai" "lofi+anime" "vocaloid" "cyberpunk+anime" "anime+art")
                query="${anime_queries[$((RANDOM % ${#anime_queries[@]}))]}"
                ;;
            cyberpunk)
                local cyber_queries=("cyberpunk" "synthwave" "neon+night" "futuristic+city" "sci-fi" "cyberpunk+cityscape")
                query="${cyber_queries[$((RANDOM % ${#cyber_queries[@]}))]}"
                ;;
            landscape)
                local land_queries=("landscape" "mountains" "scenery" "nature" "aurora" "forest+lake" "norway+landscape")
                query="${land_queries[$((RANDOM % ${#land_queries[@]}))]}"
                ;;
            space)
                local space_queries=("space" "nebula" "galaxy" "cosmos" "night+sky+stars" "astronomy" "milky+way")
                query="${space_queries[$((RANDOM % ${#space_queries[@]}))]}"
                ;;
            minimal)
                local min_queries=("minimalist" "vector+art" "clean+geometric" "flat+art" "minimal+landscape" "gradient+dark")
                query="${min_queries[$((RANDOM % ${#min_queries[@]}))]}"
                ;;
            pixelart)
                local pixel_queries=("pixel+art" "pixel+cityscape" "16bit+aesthetic" "retro+pixel+art" "pixel+scenery")
                query="${pixel_queries[$((RANDOM % ${#pixel_queries[@]}))]}"
                ;;
            *)
                local default_queries=("anime" "scenery" "cyberpunk" "landscape" "fantasy" "nature" "night+sky" "pixel+art" "cityscape" "moescape" "neon" "illustration" "digital+art")
                query="${default_queries[$((RANDOM % ${#default_queries[@]}))]}"
                if [[ $(get_time_mode 2>/dev/null || echo "dark") == "dark" ]]; then
                    query="${query}+dark"
                fi
                ;;
        esac
    fi

    log "Source: Wallhaven [q=$query purity=$purity res=${width}x${height}]"

    local api_url="https://wallhaven.cc/api/v1/search?q=${query}&categories=${categories}&purity=${purity}&sorting=random&atleast=${width}x${height}&ratios=${ratio}"
    if [[ -n "$WALLHAVEN_API_KEY" ]]; then
        api_url="${api_url}&apikey=${WALLHAVEN_API_KEY}"
    fi

    local json=""
    json=$(curl -fsSL -A "$USER_AGENT" --max-time 10 "$api_url" 2>/dev/null) || return 1

    local url=""
    url=$(printf '%s' "$json" | jq -r '.data[].path // empty' 2>/dev/null | shuf -n1)
    [[ -n "$url" ]] || return 1

    local base_name
    base_name="$(basename "$url")"
    local dest="$WALLPAPER_DIR/wh_${base_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_yande() {
    local tag_arg="${1:-}"
    local tags=""
    if [[ -n "$tag_arg" ]]; then
        tags="$tag_arg"
    else
        local yande_tags=("scenery" "landscape" "night" "sky" "city" "clouds" "stars" "original" "water" "sunset" "moon" "cyberpunk" "game_cg" "bikini" "panties" "dress")
        tags="${yande_tags[$((RANDOM % ${#yande_tags[@]}))]}"
    fi

    log "Source: Yande.re [tags=$tags]"

    local api_url="https://yande.re/post.json?limit=25&tags=${tags}"
    local json=""
    json=$(curl -fsSL -A "$USER_AGENT" --max-time 10 "$api_url" 2>/dev/null) || return 1

    local url=""
    url=$(printf '%s' "$json" | jq -r '.[].jpeg_url // .[].file_url // empty' 2>/dev/null | shuf -n1)
    [[ -n "$url" ]] || return 1

    local raw_base
    raw_base="$(printf '%s' "${url%%\?*}" | awk -F/ '{print $NF}' | sed 's/%20/_/g; s/%21/_/g; s/%28/_/g; s/%29/_/g; s/%40/_/g')"
    local clean_name
    clean_name="$(printf '%s' "$raw_base" | tr -cd '[:alnum:]_.-')"
    local dest="$WALLPAPER_DIR/yd_${clean_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_konachan() {
    local tag_arg="${1:-}"
    local tags=""
    if [[ -n "$tag_arg" ]]; then
        tags="$tag_arg"
    else
        local anime_tags=("scenery" "landscape" "night" "sky" "city" "clouds" "stars" "original" "water" "sunset" "moon" "cyberpunk" "game_cg")
        tags="${anime_tags[$((RANDOM % ${#anime_tags[@]}))]}"
    fi

    # Alternates between konachan.com (all ratings) and konachan.net
    local host="konachan.com"
    if (( RANDOM % 2 == 0 )); then host="konachan.net"; fi

    log "Source: Konachan ($host) [tags=$tags]"

    local api_url="https://${host}/post.json?limit=25&tags=${tags}"
    local json=""
    json=$(curl -fsSL -A "$USER_AGENT" --max-time 10 "$api_url" 2>/dev/null) || return 1

    local url=""
    url=$(printf '%s' "$json" | jq -r '.[].jpeg_url // .[].file_url // empty' 2>/dev/null | shuf -n1)
    [[ -n "$url" ]] || return 1

    local raw_base
    raw_base="$(printf '%s' "${url%%\?*}" | awk -F/ '{print $NF}' | sed 's/%20/_/g; s/%21/_/g; s/%28/_/g; s/%29/_/g; s/%40/_/g')"
    local clean_name
    clean_name="$(printf '%s' "$raw_base" | tr -cd '[:alnum:]_.-')"
    local dest="$WALLPAPER_DIR/kc_${clean_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_nasa_apod() {
    log "Source: NASA APOD (Astronomy 4K)"
    local rand_year=$(( 2021 + RANDOM % 5 ))
    local rand_month
    rand_month=$(printf "%02d" $(( 1 + RANDOM % 12 )))
    local rand_day
    rand_day=$(printf "%02d" $(( 1 + RANDOM % 28 )))
    local date_str="${rand_year}-${rand_month}-${rand_day}"

    local api_url="https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&date=${date_str}"
    local json=""
    json=$(curl -fsSL --max-time 10 "$api_url" 2>/dev/null) || return 1

    local url=""
    url=$(printf '%s' "$json" | jq -r '.hdurl // .url // empty' 2>/dev/null)
    [[ -n "$url" && "$url" =~ \.(jpg|jpeg|png)$ ]] || return 1

    local base_name
    base_name="$(basename "$url")"
    local dest="$WALLPAPER_DIR/nasa_${date_str}_${base_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_bing_daily() {
    log "Source: Bing Daily UHD"
    local api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US"
    local json=""
    json=$(curl -fsSL -A "$USER_AGENT" --max-time 10 "$api_url" 2>/dev/null) || return 1

    local urlbase=""
    urlbase=$(printf '%s' "$json" | jq -r '.images[].urlbase // empty' 2>/dev/null | shuf -n1)
    [[ -n "$urlbase" ]] || return 1

    local raw_name="${urlbase##*id=}"
    local clean_name
    clean_name="$(printf '%s' "${raw_name:-$urlbase}" | tr -cd '[:alnum:]_.-')"
    local dest="$WALLPAPER_DIR/bing_${clean_name}.jpg"
    local tmp_dest="${dest}.tmp"
    local url="https://www.bing.com${urlbase}_UHD.jpg"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    # Try UHD first, fallback to 1920x1080
    if ! curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        url="https://www.bing.com${urlbase}_1920x1080.jpg"
        curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1 || { rm -f "$tmp_dest"; return 1; }
    fi

    if validate_and_save_image "$tmp_dest" "$dest"; then
        echo "$dest"
        return 0
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_safebooru() {
    local tag_arg="${1:-}"
    local tags="rating:safe"
    if [[ -n "$tag_arg" ]]; then
        tags="${tags}+${tag_arg}"
    else
        local booru_tags=("scenery" "landscape" "sky" "night" "clouds" "building" "stars")
        local chosen="${booru_tags[$((RANDOM % ${#booru_tags[@]}))]}"
        tags="${tags}+${chosen}"
    fi

    log "Source: Safebooru [tags=$tags]"
    local api_url="https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=25&tags=${tags}"
    local json=""
    json=$(curl -fsSL -A "$USER_AGENT" --max-time 10 "$api_url" 2>/dev/null) || return 1

    local item=""
    item=$(printf '%s' "$json" | jq -r '.[] | "\(.directory)/\(.image)"' 2>/dev/null | shuf -n1)
    [[ -n "$item" ]] || return 1

    local url="https://safebooru.org/images/${item}"
    local base_name
    base_name="$(basename "$item")"
    local dest="$WALLPAPER_DIR/sb_${base_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -A "$USER_AGENT" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

fetch_reddit() {
    local subreddit="${REDDIT_SUBREDDITS[$((RANDOM % ${#REDDIT_SUBREDDITS[@]}))]}"
    log "Source: Reddit r/$subreddit"
    local json=""
    local custom_agent="script:wallpaper-engine:v5.5 (by /u/lucas)"

    json=$(curl -fsSL -H "User-Agent: $custom_agent" --max-time 10 "https://www.reddit.com/r/${subreddit}/top.json?t=week&limit=30" 2>/dev/null) || return 1

    local urls=""
    urls=$(printf '%s' "$json" | jq -r '
        .data.children[].data
        | if .is_gallery == true then
            .media_metadata | to_entries[] | .value.s.u
          else
            .url_overridden_by_dest
          end
        | select(. != null)
    ' 2>/dev/null | sed 's/&amp;/\&/g' | grep -E '\.(jpg|jpeg|png|webp)$' || true)

    [[ -n "$urls" ]] || return 1
    local url=""
    url=$(printf '%s\n' "$urls" | shuf -n1)
    [[ -n "$url" ]] || return 1

    local base_name
    base_name="$(basename "${url%%\?*}")"
    local dest="$WALLPAPER_DIR/reddit_${base_name}"
    local tmp_dest="${dest}.tmp"

    if [[ -f "$dest" ]]; then
        echo "$dest"
        return 0
    fi

    if curl -fsSL -H "User-Agent: $custom_agent" --max-time 25 -o "$tmp_dest" "$url" >/dev/null 2>&1; then
        if validate_and_save_image "$tmp_dest" "$dest"; then
            echo "$dest"
            return 0
        fi
    fi

    rm -f "$tmp_dest"
    return 1
}

get_local_random() {
    local subcategory="${1:-}"
    local target_dir="$WALLPAPER_DIR"

    if [[ -n "$subcategory" && -d "$WALLPAPER_DIR/$subcategory" ]]; then
        target_dir="$WALLPAPER_DIR/$subcategory"
    fi

    find "$target_dir" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' -o -name '*.mp4' -o -name '*.webm' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | shuf -n1
}

get_default_wallpaper() {
    [[ -n "${WALLPAPER_DEFAULT:-}" && -f "$WALLPAPER_DEFAULT" ]] && printf '%s\n' "$WALLPAPER_DEFAULT"
}

get_boot_wallpaper() {
    local current_wallpaper=""
    local history_wallpaper=""

    current_wallpaper="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
    if [[ -n "$current_wallpaper" && -f "$current_wallpaper" ]]; then
        printf '%s\n' "$current_wallpaper"
        return 0
    fi

    history_wallpaper="$(sed -n '1p' "$HISTORY_FILE" 2>/dev/null || true)"
    if [[ -n "$history_wallpaper" && -f "$history_wallpaper" ]]; then
        printf '%s\n' "$history_wallpaper"
        return 0
    fi

    get_default_wallpaper
}

REDDIT_SUBREDDITS=("Animewallpaper" "Moescape" "HighResAnime" "AnimeArt" "WidescreenWallpaper" "PixelArt")
