#!/usr/bin/env bash
set -euo pipefail

# shader_toggle.sh
# Usage:
#   shader_toggle.sh toggle night-light
#   shader_toggle.sh toggle grayscale
#   shader_toggle.sh status night-light
#   shader_toggle.sh status grayscale

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || { echo "missing hyprctl"; exit 1; }
    echo "ok"
    exit 0
fi

MODE="${1:-}"
SHADER="${2:-}"

if [[ -z "$MODE" || -z "$SHADER" ]]; then
    echo "Usage: shader_toggle.sh <toggle|status> <night-light|grayscale>" >&2
    exit 1
fi

SHADER_DIR="$HOME/.config/hypr/shaders"
mkdir -p "$SHADER_DIR"

if [[ "$SHADER" == "night-light" ]]; then
    SHADER_FILE="$SHADER_DIR/dynamic_night-light.glsl"
    if [[ ! -f "$SHADER_FILE" ]]; then
        cat << 'EOF' > "$SHADER_FILE"
#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float intensity = 0.50;
    float r = pixColor.r;
    float g = mix(pixColor.g, pixColor.g * 0.70, intensity);
    float b = mix(pixColor.b, pixColor.b * 0.40, intensity);
    fragColor = vec4(r, g, b, pixColor.a);
}
EOF
    fi
elif [[ "$SHADER" == "grayscale" ]]; then
    SHADER_FILE="$SHADER_DIR/dynamic_grayscale.glsl"
    if [[ ! -f "$SHADER_FILE" ]]; then
        cat << 'EOF' > "$SHADER_FILE"
#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float gray = dot(pixColor.rgb, vec3(0.299, 0.587, 0.114));
    fragColor = vec4(vec3(gray), pixColor.a);
}
EOF
    fi
else
    echo "Unknown shader: $SHADER" >&2
    exit 1
fi

CURRENT_SHADER="$(hyprctl getoption -j decoration:screen_shader 2>/dev/null | grep -o '"str": *"[^"]*"' | cut -d'"' -f4 || true)"

if [[ "$MODE" == "toggle" ]]; then
    if [[ "$CURRENT_SHADER" == "$SHADER_FILE" ]]; then
        hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null 2>&1 || true
        echo "off"
    else
        hyprctl keyword decoration:screen_shader "$SHADER_FILE" >/dev/null 2>&1 || true
        echo "on"
    fi
elif [[ "$MODE" == "status" ]]; then
    if [[ "$CURRENT_SHADER" == "$SHADER_FILE" ]]; then
        echo "on"
    else
        echo "off"
    fi
fi
