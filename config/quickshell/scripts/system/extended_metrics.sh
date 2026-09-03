#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

# Find AMDGPU device
gpu_path=""
for card in /sys/class/drm/card*/device; do
    if [[ -r "$card/vendor" ]]; then
        read -r vendor < "$card/vendor" || true
        if [[ "$vendor" == *"0x1002"* ]]; then
            gpu_path="$card"
            break
        fi
    fi
done

if [[ -z "$gpu_path" ]]; then
    echo '{"error": "No AMD GPU found"}'
    exit 0
fi

# Clock (SCLK)
sclk="0"
if [[ -r "$gpu_path/pp_dpm_sclk" ]]; then
    while IFS= read -r line; do
        if [[ "$line" == *"*"* ]]; then
            temp="${line#*: }"
            temp="${temp%Mhz*}"
            temp="${temp% *}"
            sclk="${temp//[^0-9]/}"
            break
        fi
    done < "$gpu_path/pp_dpm_sclk"
fi

# Memory Clock (MCLK)
mclk="0"
if [[ -r "$gpu_path/pp_dpm_mclk" ]]; then
    while IFS= read -r line; do
        if [[ "$line" == *"*"* ]]; then
            temp="${line#*: }"
            temp="${temp%Mhz*}"
            temp="${temp% *}"
            mclk="${temp//[^0-9]/}"
            break
        fi
    done < "$gpu_path/pp_dpm_mclk"
fi

# Find hwmon directory
hwmon_path=""
for h in "$gpu_path"/hwmon/hwmon*; do
    if [[ -d "$h" ]]; then
        hwmon_path="$h"
        break
    fi
done

# Temperature (Edge)
temp_c=0
if [[ -n "$hwmon_path" && -r "$hwmon_path/temp1_input" ]]; then
    read -r temp_raw < "$hwmon_path/temp1_input" || true
    if [[ "${temp_raw:-}" =~ ^[0-9]+$ ]]; then
        temp_c=$(( temp_raw / 1000 ))
    fi
fi

# Power (Average) in Watts
power_w="0.0"
if [[ -n "$hwmon_path" && -r "$hwmon_path/power1_average" ]]; then
    read -r power_raw < "$hwmon_path/power1_average" || true
    if [[ "${power_raw:-}" =~ ^[0-9]+$ ]]; then
        int_part=$(( power_raw / 1000000 ))
        dec_part=$(( (power_raw % 1000000) / 100000 ))
        power_w="${int_part}.${dec_part}"
    fi
fi

# Load (GPU Busy Percent)
load="0"
if [[ -r "$gpu_path/gpu_busy_percent" ]]; then
    read -r load_raw < "$gpu_path/gpu_busy_percent" || true
    if [[ "${load_raw:-}" =~ ^[0-9]+$ ]]; then
        load="$load_raw"
    fi
fi

# JSON Output
printf '{"sclk": "%s", "mclk": "%s", "temp": %d, "power": %s, "load": %s}\n' \
    "${sclk:-0}" "${mclk:-0}" "$temp_c" "$power_w" "$load"
