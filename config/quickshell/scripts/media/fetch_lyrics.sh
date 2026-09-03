#!/usr/bin/env bash
# fetch_lyrics.sh - Busca inteligente para lrclib.net
export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

if [ "${1:-}" = "--self-test" ]; then
    command -v curl >/dev/null 2>&1 || { echo "missing curl"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "missing jq"; exit 1; }
    echo "ok"
    exit 0
fi

ARTIST_RAW="$1"
TRACK_RAW="$2"

# Limpeza básica
clean_string() {
    echo "$1" | sed -E 's/ - (Spotify|YouTube|Brave|Vivaldi|Chrome|Chromium)//g' \
               | sed -E 's/ \([^)]*\)//g' \
               | sed -E 's/ \[.*\]//g' \
               | sed -E 's/^Spotify$//g' \
               | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

ARTIST=$(clean_string "$ARTIST_RAW")
TRACK=$(clean_string "$TRACK_RAW")

# Fallback se o artista estiver no título
if [ -z "$ARTIST" ] || [ "$ARTIST" = "brave" ]; then
    if [[ "$TRACK_RAW" == *" - "* ]]; then
        ARTIST=$(echo "$TRACK_RAW" | cut -d'-' -f1 | sed 's/[[:space:]]*$//')
        TRACK=$(echo "$TRACK_RAW" | cut -d'-' -f2- | sed 's/^[[:space:]]*//')
        ARTIST=$(clean_string "$ARTIST")
        TRACK=$(clean_string "$TRACK")
    fi
fi

QUERY="$ARTIST $TRACK"
ENCODED_QUERY=$(jq -rn --arg x "$QUERY" '$x|@uri')

# Busca
RESPONSE=$(curl -s -f --max-time 8 -A "Mozilla/5.0" "https://lrclib.net/api/search?q=${ENCODED_QUERY}")
FIRST_RESULT=$(echo "$RESPONSE" | jq -r '.[0] // empty')

if [ -z "$FIRST_RESULT" ] || [ "$FIRST_RESULT" == "null" ]; then
    echo "LETRA_NAO_ENCONTRADA"
    exit 0
fi

# Tenta sincronizada, senão plana
LYRICS=$(echo "$FIRST_RESULT" | jq -r '.syncedLyrics // .plainLyrics // empty')

if [ -z "$LYRICS" ] || [ "$LYRICS" == "null" ]; then
    echo "LETRA_NAO_DISPONIVEL"
else
    echo "$LYRICS"
fi
