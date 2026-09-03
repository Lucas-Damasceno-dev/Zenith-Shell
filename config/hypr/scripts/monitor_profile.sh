#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
mkdir -p "$state_dir"
LOG_FILE="${state_dir}/monitor-profile.log"
STATE_FILE="${state_dir}/monitor-profile.state"
RES_STATE_FILE="${state_dir}/monitor-res.state"
backend="${HYPR_MONITOR_BACKEND:-script}"

if [[ "${1:-}" == "--self-test" ]]; then
    command -v hyprctl >/dev/null 2>&1 || exit 1
    command -v jq >/dev/null 2>&1 || exit 1
    command -v notify-send >/dev/null 2>&1 || exit 1
    echo "ok"
    exit 0
fi

log() {
    printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$LOG_FILE"
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Monitor Profile" "$1" "${2:-}" >/dev/null 2>&1 || true
    fi
}

run_hypr() {
    local out
    if ! out="$(hyprctl "$@" 2>&1)"; then
        log "hyprctl $* failed: $out"
        return 1
    fi
    [[ -n "$out" ]] && log "hyprctl $* -> $out"
    return 0
}

if [[ "$backend" == "kanshi" ]]; then
    log "HYPR_MONITOR_BACKEND=kanshi; skipping script profile apply"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    notify "Monitor profile" "jq não encontrado"
    exit 1
fi

# Auto-resolve HYPRLAND_INSTANCE_SIGNATURE if missing in caller environment
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    base_dir="${runtime_dir}/hypr"
    if [[ -d "$base_dir" ]]; then
        while IFS= read -r dir; do
            sig="$(basename "$dir")"
            if [[ -S "${base_dir}/${sig}/.socket.sock" ]]; then
                export HYPRLAND_INSTANCE_SIGNATURE="$sig"
                break
            fi
        done < <(find "$base_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
    fi
fi

# Fetch ALL physical monitors (including currently disabled ones)
if ! all_monitors_json="$(hyprctl -j monitors all 2>/dev/null)"; then
    log "hyprctl falhou (Hyprland não está rodando?); saindo silenciosamente"
    exit 0
fi

if [[ -z "$all_monitors_json" || "$all_monitors_json" == "null" ]]; then
    notify "Monitor profile" "Não foi possível obter monitores"
    exit 1
fi

internal_monitor="$(printf '%s' "$all_monitors_json" | jq -r '[.[] | select(.name|test("^(eDP|LVDS|DSI)")) | .name][0] // ""')"
mapfile -t external_monitors < <(printf '%s' "$all_monitors_json" | jq -r '.[] | select(.name|test("^(eDP|LVDS|DSI)")|not) | .name')
primary_external="${external_monitors[0]:-}"
external_scale="${EXTERNAL_MONITOR_SCALE:-1}"
internal_scale="${INTERNAL_MONITOR_SCALE:-1}"

# Resolution handling - default to highest supported mode of external display, fallback to 1920x1080@60
default_ext_res="preferred"
if [[ -n "$primary_external" ]]; then
    highest_mode="$(printf '%s' "$all_monitors_json" | jq -r --arg tgt "$primary_external" '[.[] | select(.name == $tgt) | .availableModes[]? | split(" ")[0]][0] // ""' 2>/dev/null || echo "")"
    [[ -n "$highest_mode" && "$highest_mode" != "null" ]] && default_ext_res="$highest_mode"
fi
saved_res="$(cat "$RES_STATE_FILE" 2>/dev/null || echo "$default_ext_res")"
[[ -z "$saved_res" ]] && saved_res="$default_ext_res"

profile_arg="${1:---auto}"

assign_workspace_set() {
    local from="$1"
    local to="$2"
    local monitor="$3"
    [[ -n "$monitor" ]] || return 0
    local ws existing_workspaces
    existing_workspaces="$(hyprctl -j workspaces 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)"
    for ((ws=from; ws<=to; ws++)); do
        run_hypr keyword workspace "${ws},monitor:${monitor}" 2>/dev/null || true
        if printf '%s\n' "$existing_workspaces" | grep -qx "$ws"; then
            run_hypr dispatch moveworkspacetomonitor "${ws}" "${monitor}" 2>/dev/null || true
        fi
    done
}

case "$profile_arg" in
    status|get-state|--status|status-json)
        physical_count="$(printf '%s' "$all_monitors_json" | jq 'length' 2>/dev/null || echo 0)"
        current_state="$(cat "$STATE_FILE" 2>/dev/null || echo "internal-only")"
        if [[ "$physical_count" -le 1 && "$current_state" != "undock" && "$current_state" != "internal-only" ]]; then
            current_state="internal-only"
        fi

        target_mon="${primary_external:-$internal_monitor}"
        active_res="$(printf '%s' "$all_monitors_json" | jq -r --arg tgt "$target_mon" '[.[] | select(.name == $tgt and .disabled == false)] | .[0] | "\(.width)x\(.height)"' 2>/dev/null || echo "")"
        if [[ -z "$active_res" || "$active_res" == "null" || "$active_res" == "nullxnull" ]]; then
            active_res="${saved_res%@*}"
        fi

        # Extract available modes list for primary target
        modes_list="$(printf '%s' "$all_monitors_json" | jq -r --arg tgt "$target_mon" '
            [.[] | select(.name == $tgt) | .availableModes[]? | split(" ")[0] | split("@")[0]] | unique | reverse | join(",")
        ' 2>/dev/null || echo "")"
        if [[ -z "$modes_list" ]]; then
            modes_list="1920x1080,1366x768,1280x720,preferred"
        else
            modes_list="${modes_list},preferred"
        fi

        # Extract structured monitors JSON
        monitors_compact_json="$(printf '%s' "$all_monitors_json" | jq -c '[.[] | {
            id: .id,
            name: .name,
            model: (if .model == "" or .model == null then .name else .model end),
            make: (if .make == "" or .make == null then "Generic" else .make end),
            description: .description,
            width: .width,
            height: .height,
            refreshRate: (.refreshRate | round),
            scale: .scale,
            transform: .transform,
            focused: .focused,
            disabled: .disabled,
            mirrorOf: .mirrorOf,
            isInternal: (.name | test("^(eDP|LVDS|DSI)")),
            availableModes: [.availableModes[]? | split(" ")[0]]
        }]' 2>/dev/null || echo "[]")"

        printf 'profile=%s\nresolution=%s\nmonitors_count=%s\nexternal_name=%s\ninternal_name=%s\navailable_resolutions=%s\nmonitors_json=%s\n' \
            "$current_state" "$active_res" "$physical_count" "$primary_external" "$internal_monitor" "$modes_list" "$monitors_compact_json"
        exit 0
        ;;

    --identify|identify)
        mapfile -t active_mons < <(printf '%s' "$all_monitors_json" | jq -c '.[] | select(.disabled == false)')
        for mon_data in "${active_mons[@]}"; do
            m_name="$(printf '%s' "$mon_data" | jq -r '.name')"
            m_model="$(printf '%s' "$mon_data" | jq -r '.model // .name')"
            m_w="$(printf '%s' "$mon_data" | jq -r '.width')"
            m_h="$(printf '%s' "$mon_data" | jq -r '.height')"
            m_hz="$(printf '%s' "$mon_data" | jq -r '.refreshRate | round')"
            m_scale="$(printf '%s' "$mon_data" | jq -r '.scale')"
            
            hyprctl notify 1 4000 "rgb(89b4fa)" "Monitor: ${m_name} (${m_w}x${m_h}@${m_hz}Hz, ${m_scale}x)" >/dev/null 2>&1 || true
            notify "Identificação de Monitor" "${m_name} • ${m_model}\n${m_w}x${m_h} @ ${m_hz}Hz (Escala: ${m_scale}x)"
        done
        exit 0
        ;;

    --set-scale|set-scale)
        target_name="${2:-${primary_external:-$internal_monitor}}"
        target_scale="${3:-1}"
        m_mode="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0] | "\(.width)x\(.height)@\(.refreshRate)"' 2>/dev/null || echo "preferred")"
        m_trans="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0].transform // 0' 2>/dev/null || echo 0)"
        [[ "$m_mode" == "nullxnull@null" || -z "$m_mode" ]] && m_mode="preferred"
        
        run_hypr keyword monitor "${target_name},${m_mode},auto,${target_scale},transform,${m_trans}" || true
        notify "Monitor Profile" "Escala de ${target_name} alterada para ${target_scale}x"
        exit 0
        ;;

    --set-transform|set-transform)
        target_name="${2:-${primary_external:-$internal_monitor}}"
        target_trans="${3:-0}"
        m_mode="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0] | "\(.width)x\(.height)@\(.refreshRate)"' 2>/dev/null || echo "preferred")"
        m_scale="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0].scale // 1' 2>/dev/null || echo 1)"
        [[ "$m_mode" == "nullxnull@null" || -z "$m_mode" ]] && m_mode="preferred"
        
        run_hypr keyword monitor "${target_name},${m_mode},auto,${m_scale},transform,${target_trans}" || true
        notify "Monitor Profile" "Orientação de ${target_name} atualizada (${target_trans} rot)"
        exit 0
        ;;

    --set-monitor-mode|set-monitor-mode)
        target_name="${2:-${primary_external:-$internal_monitor}}"
        target_mode="${3:-preferred}"
        target_scale="${4:-1}"
        target_trans="${5:-0}"
        
        run_hypr keyword monitor "${target_name},${target_mode},auto,${target_scale},transform,${target_trans}" || true
        notify "Monitor Profile" "${target_name}: modo ${target_mode} aplicado"
        exit 0
        ;;

    --res-1366|res-1366)
        saved_res="1366x768@60"
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        notify "Monitor Profile" "Resolução alterada para 1366x768"
        ;;
    --res-1080|res-1080)
        saved_res="1920x1080@60"
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        notify "Monitor Profile" "Resolução alterada para 1920x1080 (Full HD)"
        ;;
    --res-720|res-720)
        saved_res="1280x720@60"
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        notify "Monitor Profile" "Resolução alterada para 1280x720"
        ;;
    --res-auto|res-auto|--res-preferred|res-preferred)
        saved_res="preferred"
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        notify "Monitor Profile" "Resolução restaurada para Automática / Nativa"
        ;;
    --set-res|set-res)
        custom_res="${2:-1366x768@60}"
        if [[ "$custom_res" =~ ^[0-9]+x[0-9]+$ ]]; then
            custom_res="${custom_res}@60"
        fi
        saved_res="$custom_res"
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        notify "Monitor Profile" "Resolução definida para: ${custom_res}"
        ;;
    --cycle-res|cycle-res)
        target_name="${2:-${primary_external:-$internal_monitor}}"
        mapfile -t supported_modes < <(printf '%s' "$all_monitors_json" | jq -r --arg tgt "$target_name" '
            [.[] | select(.name == $tgt) | .availableModes[]? | split(" ")[0]] | unique | reverse | .[]
        ' 2>/dev/null || echo "")
        
        if [[ "${#supported_modes[@]}" -gt 0 ]]; then
            next_mode="${supported_modes[0]}"
            for i in "${!supported_modes[@]}"; do
                if [[ "${supported_modes[$i]}" == "$saved_res"* ]]; then
                    next_idx=$(( (i + 1) % ${#supported_modes[@]} ))
                    next_mode="${supported_modes[$next_idx]}"
                    break
                fi
            done
            saved_res="$next_mode"
        else
            case "$saved_res" in
                *1366x768*) saved_res="1920x1080@60" ;;
                *1920x1080*) saved_res="1280x720@60" ;;
                *1280x720*) saved_res="preferred" ;;
                *) saved_res="1366x768@60" ;;
            esac
        fi
        printf '%s\n' "$saved_res" > "$RES_STATE_FILE"
        m_scale="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0].scale // 1' 2>/dev/null || echo 1)"
        m_trans="$(printf '%s' "$all_monitors_json" | jq -r --arg m "$target_name" '[.[] | select(.name == $m)] | .[0].transform // 0' 2>/dev/null || echo 0)"
        run_hypr keyword monitor "${target_name},${saved_res},auto,${m_scale},transform,${m_trans}" || true
        notify "Monitor Profile" "${target_name}: Resolução alternada para ${saved_res}"
        exit 0
        ;;
    --dock|dock|--extend|extend|--extend-right|extend-right)
        profile_mode="extend-right"
        ;;
    --extend-left|extend-left)
        profile_mode="extend-left"
        ;;
    --extend-above|extend-above)
        profile_mode="extend-above"
        ;;
    --undock|undock|--laptop-only|laptop-only|--internal-only|internal-only)
        profile_mode="internal-only"
        ;;
    --mirror|mirror)
        profile_mode="mirror"
        ;;
    --external-only|external-only)
        profile_mode="external-only"
        ;;
    --cycle|cycle)
        current_state="$(cat "$STATE_FILE" 2>/dev/null || echo "dock")"
        if [[ "${#external_monitors[@]}" -eq 0 ]]; then
            notify "Monitor Profile" "Nenhum monitor externo conectado"
            exit 0
        fi
        case "$current_state" in
            dock|extend|extend-right) profile_mode="extend-left" ;;
            extend-left) profile_mode="mirror" ;;
            mirror) profile_mode="external-only" ;;
            external-only) profile_mode="internal-only" ;;
            *) profile_mode="extend-right" ;;
        esac
        ;;
    --auto|auto)
        if [[ "${#external_monitors[@]}" -gt 0 ]]; then
            profile_mode="$(cat "$STATE_FILE" 2>/dev/null || echo "extend-right")"
            [[ "$profile_mode" == "undock" || "$profile_mode" == "internal-only" ]] && profile_mode="extend-right"
        else
            profile_mode="internal-only"
        fi
        ;;
    *)
        notify "Monitor Profile" "Modo inválido: $profile_arg"
        exit 1
        ;;
esac

# Fallback to internal-only if external requested but physically absent
if [[ "$profile_mode" =~ ^(dock|extend|extend-right|extend-left|extend-above|mirror|external-only)$ && "${#external_monitors[@]}" -eq 0 ]]; then
    log "Ação para monitor externo requisitada, mas nenhum monitor externo físico conectado; aplicando internal-only"
    profile_mode="internal-only"
fi

printf '%s\n' "$profile_mode" > "$STATE_FILE"

# 1. MODO ESTENDER PARA A DIREITA (EXTEND RIGHT / DOCK)
if [[ "$profile_mode" == "dock" || "$profile_mode" == "extend" || "$profile_mode" == "extend-right" ]]; then
    ext_mode="$saved_res"
    [[ -z "$ext_mode" ]] && ext_mode="preferred"

    run_hypr keyword monitor "${internal_monitor},preferred,0x0,${internal_scale}" || true
    run_hypr keyword monitor "${primary_external},${ext_mode},auto-right,${external_scale}" || true

    if [[ -n "$internal_monitor" && -n "$primary_external" && "$internal_monitor" != "$primary_external" ]]; then
        assign_workspace_set 1 5 "$internal_monitor"
        assign_workspace_set 6 10 "$primary_external"
    else
        assign_workspace_set 1 10 "${primary_external:-$internal_monitor}"
    fi

    run_hypr keyword xwayland:force_zero_scaling false || true
    printf 'extend-right\n' > "$STATE_FILE"
    notify "Monitor Profile" "Estendido (Direita): ${internal_monitor} + ${primary_external} (${ext_mode})"
    exit 0
fi

# 2. MODO ESTENDER PARA A ESQUERDA (EXTEND LEFT)
if [[ "$profile_mode" == "extend-left" ]]; then
    ext_mode="$saved_res"
    [[ -z "$ext_mode" ]] && ext_mode="preferred"

    run_hypr keyword monitor "${primary_external},${ext_mode},0x0,${external_scale}" || true
    run_hypr keyword monitor "${internal_monitor},preferred,auto-right,${internal_scale}" || true

    if [[ -n "$internal_monitor" && -n "$primary_external" && "$internal_monitor" != "$primary_external" ]]; then
        assign_workspace_set 1 5 "$internal_monitor"
        assign_workspace_set 6 10 "$primary_external"
    else
        assign_workspace_set 1 10 "${primary_external:-$internal_monitor}"
    fi

    run_hypr keyword xwayland:force_zero_scaling false || true
    printf 'extend-left\n' > "$STATE_FILE"
    notify "Monitor Profile" "Estendido (Esquerda): ${primary_external} (${ext_mode}) + ${internal_monitor}"
    exit 0
fi

# 3. MODO ESTENDER ACIMA (EXTEND ABOVE)
if [[ "$profile_mode" == "extend-above" ]]; then
    ext_mode="$saved_res"
    [[ -z "$ext_mode" ]] && ext_mode="preferred"

    run_hypr keyword monitor "${primary_external},${ext_mode},0x0,${external_scale}" || true
    run_hypr keyword monitor "${internal_monitor},preferred,auto-down,${internal_scale}" || true

    if [[ -n "$internal_monitor" && -n "$primary_external" && "$internal_monitor" != "$primary_external" ]]; then
        assign_workspace_set 1 5 "$internal_monitor"
        assign_workspace_set 6 10 "$primary_external"
    else
        assign_workspace_set 1 10 "${primary_external:-$internal_monitor}"
    fi

    run_hypr keyword xwayland:force_zero_scaling false || true
    printf 'extend-above\n' > "$STATE_FILE"
    notify "Monitor Profile" "Estendido (Acima): ${primary_external} (${ext_mode}) sobre ${internal_monitor}"
    exit 0
fi

# 4. MODO ESPELHADO (MIRROR)
if [[ "$profile_mode" == "mirror" ]]; then
    mirror_src="$internal_monitor"
    if [[ -z "$mirror_src" && "${#external_monitors[@]}" -gt 1 ]]; then
        mirror_src="${external_monitors[0]}"
        primary_external="${external_monitors[1]}"
    fi

    if [[ -n "$mirror_src" && -n "$primary_external" ]]; then
        ext_mode="$saved_res"
        [[ -z "$ext_mode" ]] && ext_mode="preferred"

        run_hypr keyword monitor "${mirror_src},preferred,0x0,${internal_scale}" || true
        run_hypr keyword monitor "${primary_external},${ext_mode},auto,${external_scale},mirror,${mirror_src}" || true
        assign_workspace_set 1 10 "$mirror_src"
        run_hypr keyword xwayland:force_zero_scaling false || true
        printf 'mirror\n' > "$STATE_FILE"
        notify "Monitor Profile" "Modo Espelhado: ${mirror_src} -> ${primary_external} (${ext_mode})"
    else
        notify "Monitor Profile" "Espelhamento indisponível (requer 2+ telas conectadas)"
    fi
    exit 0
fi

# 5. MODO APENAS EXTERNO (TV / MONITOR EXTERNO)
if [[ "$profile_mode" == "external-only" ]]; then
    if [[ -n "$primary_external" ]]; then
        ext_mode="$saved_res"
        [[ -z "$ext_mode" ]] && ext_mode="preferred"

        if [[ -n "$internal_monitor" && "$internal_monitor" != "$primary_external" ]]; then
            run_hypr keyword monitor "${internal_monitor},disable" || true
        fi
        run_hypr keyword monitor "${primary_external},${ext_mode},0x0,${external_scale}" || true
        assign_workspace_set 1 10 "$primary_external"
        run_hypr keyword xwayland:force_zero_scaling false || true
        printf 'external-only\n' > "$STATE_FILE"
        notify "Monitor Profile" "Apenas TV / Monitor Externo: ${primary_external} (${ext_mode})"
    fi
    exit 0
fi

# 6. MODO APENAS NOTEBOOK (INTERNAL ONLY / UNDOCK)
for ext in "${external_monitors[@]}"; do
    [[ -n "$ext" ]] && run_hypr keyword monitor "${ext},disable" || true
done

fallback_monitor="$internal_monitor"
if [[ -z "$fallback_monitor" ]]; then
    fallback_monitor="$(printf '%s' "$all_monitors_json" | jq -r '.[0].name // ""')"
fi

if [[ -z "$fallback_monitor" ]]; then
    notify "Monitor Profile" "Nenhum monitor disponível"
    exit 1
fi

undocked_scale="${UNDOCKED_MONITOR_SCALE:-1}"
notebook_mode="${saved_res:-preferred}"
[[ -z "$notebook_mode" ]] && notebook_mode="preferred"
run_hypr keyword monitor "${fallback_monitor},${notebook_mode},0x0,${undocked_scale}" || true
assign_workspace_set 1 10 "$fallback_monitor"
run_hypr keyword xwayland:force_zero_scaling false || true

printf 'internal-only\n' > "$STATE_FILE"
notify "Monitor Profile" "Apenas Notebook: ${fallback_monitor}"
