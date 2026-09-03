#!/usr/bin/env bash
# Remove set -e to allow the script to continue if some commands (like du) fail partially
set -uo pipefail

# Ensure standard paths are available
if [[ -d "/run/current-system/sw/bin" ]]; then
  if [[ -n "${PATH:-}" ]]; then
    export PATH="${PATH}:/run/current-system/sw/bin"
  else
    export PATH="/run/current-system/sw/bin"
  fi
fi

if [[ "${1:-}" == "--self-test" ]]; then
    command -v df >/dev/null 2>&1 || exit 1
    command -v awk >/dev/null 2>&1 || exit 1
    echo ok
    exit 0
fi

# Get overall root partition usage
root_line="$(df -h / 2>/dev/null | awk 'NR==2')"
root_dev="" root_used="" root_free="" root_use_pct=""
if [[ -n "$root_line" ]]; then
    read -r root_dev _ root_used root_free root_use_pct _ <<< "$root_line"
    root_use_pct="${root_use_pct%\%}"
fi

root_info="--"
[[ -n "$root_used" && -n "$root_free" ]] && root_info="${root_used} used / ${root_free} free"
[[ -z "$root_use_pct" ]] && root_use_pct="--"

# Check /home partition
home_line="$(df -h /home 2>/dev/null | awk 'NR==2')"
home_dev="" home_used="" home_free=""
if [[ -n "$home_line" ]]; then
    read -r home_dev _ home_used home_free _ <<< "$home_line"
fi

home_info=""
if [[ -n "$root_dev" && -n "$home_dev" && "$root_dev" == "$home_dev" ]]; then
    # Home is on the same partition as root
    home_path="${HOME:-/home}"
    home_target="/home"
    if [[ ! -d "$home_target" ]]; then
        home_target="$home_path"
    fi

    # Check cache first (TTL 1800s / 30 min)
    cache_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
    cache_file="${cache_dir}/home-du.cache"
    home_du=""
    now="$(date +%s)"

    if [[ -f "$cache_file" ]]; then
        cache_mtime="$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)"
        if (( now - cache_mtime < 1800 )); then
            home_du="$(<"$cache_file")"
        fi
    fi

    if [[ -z "$home_du" ]]; then
        home_du="$(timeout 0.5s du -sh "$home_path" 2>/dev/null | awk '{print $1}' || echo "")"
        if [[ -z "$home_du" && "$home_target" != "$home_path" && -d "$home_target" ]]; then
            home_du="$(timeout 0.5s du -sh "$home_target" 2>/dev/null | awk '{print $1}' || echo "")"
        fi
        if [[ -n "$home_du" ]]; then
            mkdir -p "$cache_dir" 2>/dev/null || true
            printf '%s\n' "$home_du" > "$cache_file" 2>/dev/null || true
        fi
    fi

    if [[ -n "$home_du" ]]; then
        # Show home usage with percentage of root filesystem
        if [[ "$root_use_pct" != "--" ]]; then
            home_info="${home_du} used (${root_use_pct}% of /)"
        else
            home_info="${home_du} used"
        fi
    else
        # Fallback: when du times out, show root partition info with indicator
        home_info="${root_info} (shared)"
    fi
else
    # Home is a separate partition, show partition usage
    if [[ -n "$home_used" && -n "$home_free" ]]; then
        home_info="${home_used} used / ${home_free} free"
    fi
fi

# Ensure we have valid output
[[ -z "$home_info" || "$home_info" == " used /  free" ]] && home_info="--"

printf 'root=%s\nhome=%s\n' "$root_info" "$home_info"
