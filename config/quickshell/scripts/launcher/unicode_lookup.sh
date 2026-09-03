#!/usr/bin/env bash
# shellcheck disable=SC1111
set -euo pipefail

# Unicode character lookup and search
# Usage: unicode_lookup.sh <search_term>

if [[ "${1:-}" == "--self-test" ]]; then
    echo "ok"
    exit 0
fi

search_term="${1:-}"
[[ -z "$search_term" ]] && exit 0

# Common Unicode characters database (name -> codepoint -> character)
# This is a curated subset of commonly needed symbols
declare -A UNICODE_DB=(
    # Arrows
    ["arrow right"]="U+2192 →"
    ["arrow left"]="U+2190 ←"
    ["arrow up"]="U+2191 ↑"
    ["arrow down"]="U+2193 ↓"
    ["double arrow right"]="U+21D2 ⇒"
    ["double arrow left"]="U+21D0 ⇐"
    ["arrow both"]="U+2194 ↔"
    
    # Math symbols
    ["not equal"]="U+2260 ≠"
    ["approximately"]="U+2248 ≈"
    ["less equal"]="U+2264 ≤"
    ["greater equal"]="U+2265 ≥"
    ["plus minus"]="U+00B1 ±"
    ["multiply"]="U+00D7 ×"
    ["divide"]="U+00F7 ÷"
    ["infinity"]="U+221E ∞"
    ["sum"]="U+2211 ∑"
    ["product"]="U+220F ∏"
    ["integral"]="U+222B ∫"
    ["square root"]="U+221A √"
    ["partial"]="U+2202 ∂"
    ["delta"]="U+0394 Δ"
    ["pi"]="U+03C0 π"
    ["theta"]="U+03B8 θ"
    ["lambda"]="U+03BB λ"
    ["omega"]="U+03C9 ω"
    ["alpha"]="U+03B1 α"
    ["beta"]="U+03B2 β"
    ["gamma"]="U+03B3 γ"
    ["sigma"]="U+03C3 σ"
    ["mu"]="U+03BC μ"
    
    # Logic
    ["and"]="U+2227 ∧"
    ["or"]="U+2228 ∨"
    ["not"]="U+00AC ¬"
    ["implies"]="U+21D2 ⇒"
    ["iff"]="U+21D4 ⇔"
    ["forall"]="U+2200 ∀"
    ["exists"]="U+2203 ∃"
    ["element of"]="U+2208 ∈"
    ["subset"]="U+2282 ⊂"
    ["superset"]="U+2283 ⊃"
    ["union"]="U+222A ∪"
    ["intersection"]="U+2229 ∩"
    ["empty set"]="U+2205 ∅"
    
    # Currency
    ["euro"]="U+20AC €"
    ["pound"]="U+00A3 £"
    ["yen"]="U+00A5 ¥"
    ["cent"]="U+00A2 ¢"
    ["bitcoin"]="U+20BF ₿"
    
    # Typography
    ["bullet"]="U+2022 •"
    ["ellipsis"]="U+2026 …"
    ["em dash"]="U+2014 —"
    ["en dash"]="U+2013 –"
    ["degree"]="U+00B0 °"
    ["copyright"]="U+00A9 ©"
    ["registered"]="U+00AE ®"
    ["trademark"]="U+2122 ™"
    ["section"]="U+00A7 §"
    ["paragraph"]="U+00B6 ¶"
    ["dagger"]="U+2020 †"
    ["double dagger"]="U+2021 ‡"
    
    # Quotes
    ["left double quote"]="U+201C “"
    ["right double quote"]="U+201D ”"
    ["left single quote"]="U+2018 ‘"
    ["right single quote"]="U+2019 ’"
    ["left guillemet"]="U+00AB «"
    ["right guillemet"]="U+00BB »"
    
    # Checkmarks and status
    ["checkmark"]="U+2713 ✓"
    ["heavy check"]="U+2714 ✔"
    ["cross mark"]="U+2717 ✗"
    ["heavy cross"]="U+2718 ✘"
    ["star"]="U+2605 ★"
    ["star outline"]="U+2606 ☆"
    ["heart"]="U+2665 ♥"
    ["diamond"]="U+2666 ♦"
    ["spade"]="U+2660 ♠"
    ["club"]="U+2663 ♣"
    
    # Misc symbols
    ["warning"]="U+26A0 ⚠"
    ["info"]="U+2139 ℹ"
    ["telephone"]="U+260E ☎"
    ["music note"]="U+266A ♪"
    ["sun"]="U+2600 ☀"
    ["cloud"]="U+2601 ☁"
    ["umbrella"]="U+2602 ☂"
    ["snowflake"]="U+2744 ❄"
    ["lightning"]="U+26A1 ⚡"
    
    # Nix/Programming
    ["nix"]="U+2744 ❄"
    ["lambda"]="U+03BB λ"
    ["function"]="U+0192 ƒ"
    ["null"]="U+2205 ∅"
    
    # Box drawing
    ["box horizontal"]="U+2500 ─"
    ["box vertical"]="U+2502 │"
    ["box corner tl"]="U+250C ┌"
    ["box corner tr"]="U+2510 ┐"
    ["box corner bl"]="U+2514 └"
    ["box corner br"]="U+2518 ┘"
    ["box cross"]="U+253C ┼"
    
    # Fractions
    ["half"]="U+00BD ½"
    ["quarter"]="U+00BC ¼"
    ["three quarters"]="U+00BE ¾"
    ["third"]="U+2153 ⅓"
    ["two thirds"]="U+2154 ⅔"
)

# Search function
search_lower="${search_term,,}"
found=0

# First, check if input is a hex codepoint (e.g., "2192" or "U+2192")
if [[ "$search_term" =~ ^[Uu]\+?([0-9A-Fa-f]{4,6})$ ]] || [[ "$search_term" =~ ^([0-9A-Fa-f]{4,6})$ ]]; then
    hex="${BASH_REMATCH[1]}"
    # Convert hex to character
    char=$(printf "\\U%s" "$hex" 2>/dev/null || echo "")
    if [[ -n "$char" ]]; then
        printf '%s\tU+%s\t%s\t%s\n' "$char" "$hex" "Codepoint" "copy"
        found=1
    fi
fi

# Search in database
for name in "${!UNICODE_DB[@]}"; do
    name_lower="${name,,}"
    if [[ "$name_lower" == *"$search_lower"* ]]; then
        value="${UNICODE_DB[$name]}"
        codepoint="${value%% *}"
        char="${value##* }"
        printf '%s\t%s\t%s\t%s\n' "$char" "$codepoint" "$name" "copy"
        ((found++))
    fi
done

# If nothing found and search is 1-2 chars, show the codepoint for those chars
if [[ $found -eq 0 && ${#search_term} -le 2 && ${#search_term} -ge 1 ]]; then
    for ((i=0; i<${#search_term}; i++)); do
        char="${search_term:$i:1}"
        # Get codepoint using printf
        codepoint=$(printf '%04X' "'$char" 2>/dev/null || echo "")
        if [[ -n "$codepoint" ]]; then
            printf '%s\tU+%s\t%s\t%s\n' "$char" "$codepoint" "Character info" "copy"
            ((found++))
        fi
    done
fi

exit 0
