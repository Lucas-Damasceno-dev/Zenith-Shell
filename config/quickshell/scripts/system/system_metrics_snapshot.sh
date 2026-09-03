#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime_paths.sh
source "$script_dir/../lib/runtime_paths.sh"
qs_ensure_dirs

if [[ "${1:-}" == "--self-test" ]]; then
  [[ -r /proc/stat ]] || { echo "missing /proc/stat"; exit 1; }
  [[ -r /proc/meminfo ]] || { echo "missing /proc/meminfo"; exit 1; }
  echo "ok"
  exit 0
fi

# ─── CPU Stats ──────────────────────────────────────────────────
cpu_usage="0"
read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
idle_total=$((idle + iowait))
non_idle=$((user + nice + system + irq + softirq + steal))
current_total=$((idle_total + non_idle))

# In-script fallback delta if state file exists (or output raw ticks for QML memory delta)
cpu_state_file="$(qs_runtime_file 'metrics-cpu.state')"
if [[ -f "$cpu_state_file" ]]; then
  read -r prev_total prev_idle < "$cpu_state_file" || true
  if [[ "${prev_total:-}" =~ ^[0-9]+$ ]] && [[ "${prev_idle:-}" =~ ^[0-9]+$ ]]; then
    diff_total=$((current_total - prev_total))
    diff_idle=$((idle_total - prev_idle))
    if (( diff_total > 0 )); then
      cpu_usage=$(( (100 * (diff_total - diff_idle)) / diff_total ))
    fi
  fi
fi
printf '%s %s\n' "$current_total" "$idle_total" > "$cpu_state_file"

# ─── RAM Stats ──────────────────────────────────────────────────
mem_total="0"
mem_available="0"
while read -r key value _; do
  case "$key" in
    MemTotal:) mem_total="$value" ;;
    MemAvailable:) mem_available="$value" ;;
  esac
done < /proc/meminfo

ram_usage="0"
ram_used_mb="0"
ram_total_mb="0"
if [[ "$mem_total" =~ ^[0-9]+$ ]] && [[ "$mem_available" =~ ^[0-9]+$ ]] && (( mem_total > 0 )); then
  ram_usage=$(( (100 * (mem_total - mem_available)) / mem_total ))
  ram_used_mb=$(( (mem_total - mem_available) / 1024 ))
  ram_total_mb=$(( mem_total / 1024 ))
fi

# ─── GPU Stats (AMD / Intel / Nvidia) ───────────────────────────
gpu_usage="0"
for _g in /sys/class/drm/card*/device/gpu_busy_percent; do
  if [[ -r "$_g" ]]; then
    read -r _gval < "$_g" 2>/dev/null || true
    if [[ "${_gval:-}" =~ ^[0-9]+$ ]]; then
      gpu_usage="$_gval"
      break
    fi
  fi
done

if [[ "$gpu_usage" == "0" ]] && command -v nvidia-smi >/dev/null 2>&1; then
  _nv_val="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d ' ' || echo "0")"
  if [[ "$_nv_val" =~ ^[0-9]+$ ]]; then
    gpu_usage="$_nv_val"
  fi
fi

# ─── Temperature (hwmon / zenpower / coretemp / k10temp) ────────
hwmon_cache_file="$(qs_runtime_file 'hwmon-temp-path.cache')"
temp_path=""
if [[ -f "$hwmon_cache_file" ]]; then
  read -r temp_path < "$hwmon_cache_file" 2>/dev/null || true
  [[ -r "$temp_path" ]] || temp_path=""
fi
if [[ -z "$temp_path" ]]; then
  for _h in /sys/class/hwmon/hwmon*/name; do
    if [[ -r "$_h" ]]; then
      read -r _hname < "$_h" 2>/dev/null || true
      if [[ "$_hname" == *"k10temp"* ]] || [[ "$_hname" == *"coretemp"* ]] || [[ "$_hname" == *"zenpower"* ]]; then
        _hbase="${_h%/name}"
        if [[ -r "${_hbase}/temp1_input" ]]; then
          temp_path="${_hbase}/temp1_input"
          break
        fi
      fi
    fi
  done
  if [[ -z "$temp_path" && -r /sys/class/thermal/thermal_zone0/temp ]]; then
    temp_path="/sys/class/thermal/thermal_zone0/temp"
  fi
  [[ -n "$temp_path" ]] && printf '%s\n' "$temp_path" > "$hwmon_cache_file"
fi

temp_c="0"
if [[ -n "$temp_path" && -r "$temp_path" ]]; then
  read -r temp_raw < "$temp_path" 2>/dev/null || true
  if [[ "${temp_raw:-}" =~ ^[0-9]+$ ]]; then
    temp_c=$(( temp_raw / 1000 ))
  fi
fi

echo "cpu_total=${current_total}"
echo "cpu_idle=${idle_total}"
echo "cpu=${cpu_usage}"
echo "ram=${ram_usage}"
echo "ram_used_mb=${ram_used_mb}"
echo "ram_total_mb=${ram_total_mb}"
echo "gpu=${gpu_usage}"
echo "temp=${temp_c}"
