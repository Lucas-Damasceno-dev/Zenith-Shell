#!/usr/bin/env bash
set -euo pipefail
unset LD_LIBRARY_PATH
export LC_ALL=C

# shader_intensity.sh
# Usage:
#   shader_intensity.sh get <type>
#   shader_intensity.sh get-all
#   shader_intensity.sh set <type> <intensity>
#   shader_intensity.sh set-all <night-light-val> <grayscale-val>

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Auto-discover active Hyprland socket if instance signature is missing or stale
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || ! -S "${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]]; then
    if [[ -d "$XDG_RUNTIME_DIR/hypr" ]]; then
        HYPR_SIG="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
        if [[ -n "$HYPR_SIG" ]]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
        fi
    fi
fi

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || { echo "missing hyprctl"; exit 1; }
    command -v awk >/dev/null 2>&1 || { echo "missing awk"; exit 1; }
    command -v sed >/dev/null 2>&1 || { echo "missing sed"; exit 1; }
    echo "ok"
    exit 0
fi

COMMAND="${1:-}"

SHADER_DIR="$HOME/.config/hypr/shaders"
mkdir -p "$SHADER_DIR"

STATE_FILE="$SHADER_DIR/shader_state.txt"

# Initialize state file if it doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
    printf 'night-light=0\ngrayscale=0\n' > "$STATE_FILE"
fi

get_intensity() {
    local t="$1"
    local val
    val="$(grep "^$t=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 || true)"
    echo "${val:-0}"
}

set_intensity() {
    local t="$1"
    local val="$2"
    if [[ ! "$val" =~ ^[0-9]+$ ]]; then val=0; fi
    if (( val < 0 )); then val=0; fi
    if (( val > 100 )); then val=100; fi
    
    if grep -q "^$t=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^$t=.*/$t=$val/" "$STATE_FILE"
    else
        echo "$t=$val" >> "$STATE_FILE"
    fi
    echo "$val"
}

apply_shaders() {
    local night_val="$1"
    local gray_val="$2"
    
    local night_float
    local gray_float
    night_float="$(awk "BEGIN {printf \"%.2f\", $night_val / 100.0}")"
    gray_float="$(awk "BEGIN {printf \"%.2f\", $gray_val / 100.0}")"
    
    if (( night_val == 0 && gray_val == 0 )); then
        local res
        res="$(hyprctl keyword decoration:screen_shader "" 2>&1 || true)"
        echo "[shader_intensity] disabled shader: $res (sig=${HYPRLAND_INSTANCE_SIGNATURE:-none})" >&2
        return 0
    fi
    
    # Alternate between double buffers to ensure Hyprland detects a changed path and recompiles
    local current_shader
    current_shader="$(hyprctl getoption decoration:screen_shader -j 2>/dev/null | grep -o '"str": *"[^"]*"' | cut -d'"' -f4 || true)"
    
    local shader_file="$SHADER_DIR/active_screen_shader_a.glsl"
    if [[ "$current_shader" == *active_screen_shader_a.glsl ]]; then
        shader_file="$SHADER_DIR/active_screen_shader_b.glsl"
    fi
    
    cat << EOF > "$shader_file"
#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    
    // Grayscale
    float grayIntensity = $gray_float;
    if (grayIntensity > 0.0) {
        float gray = dot(pixColor.rgb, vec3(0.299, 0.587, 0.114));
        pixColor.rgb = mix(pixColor.rgb, vec3(gray), grayIntensity);
    }
    
    // Night light (warm filter / blue light filter)
    float nightIntensity = $night_float;
    if (nightIntensity > 0.0) {
        pixColor.g = mix(pixColor.g, pixColor.g * 0.85, nightIntensity);
        pixColor.b = mix(pixColor.b, pixColor.b * 0.35, nightIntensity);
    }
    
    fragColor = pixColor;
}
EOF

    local out
    out="$(hyprctl keyword decoration:screen_shader "$shader_file" 2>&1 || true)"
    echo "[shader_intensity] applied $shader_file (night=$night_val, gray=$gray_val): $out (sig=${HYPRLAND_INSTANCE_SIGNATURE:-none})" >&2
}

if [[ "$COMMAND" == "get-all" ]]; then
    cat "$STATE_FILE" 2>/dev/null || printf 'night-light=0\ngrayscale=0\n'
    exit 0
elif [[ "$COMMAND" == "get" ]]; then
    TYPE="${2:-night-light}"
    get_intensity "$TYPE"
    exit 0
elif [[ "$COMMAND" == "set-all" ]]; then
    NIGHT_VAL="${2:-0}"
    GRAY_VAL="${3:-0}"
    NIGHT_CLEAN="$(set_intensity "night-light" "$NIGHT_VAL")"
    GRAY_CLEAN="$(set_intensity "grayscale" "$GRAY_VAL")"
    apply_shaders "$NIGHT_CLEAN" "$GRAY_CLEAN"
    echo "$NIGHT_CLEAN $GRAY_CLEAN"
    exit 0
elif [[ "$COMMAND" == "set" ]]; then
    TYPE="${2:-night-light}"
    INTENSITY="${3:-0}"
    set_intensity "$TYPE" "$INTENSITY" >/dev/null
    NIGHT_VAL="$(get_intensity "night-light")"
    GRAY_VAL="$(get_intensity "grayscale")"
    apply_shaders "$NIGHT_VAL" "$GRAY_VAL"
    get_intensity "$TYPE"
    exit 0
else
    echo "Usage: shader_intensity.sh <get|get-all|set|set-all> [args...]" >&2
    exit 1
fi
