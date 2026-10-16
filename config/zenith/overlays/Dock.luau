--!strict
-- Zenith-Shell (Engine v2) - Floating Glassmorphic Wayland Bottom Dock
-- Parity 1:1 with Quickshell dock, Hyprland client tracking, spring physics and focus:<address>.
-- Modules: Launcher, Quick Utilities (Terminal & Screenshot), Pinned Apps, Unpinned Apps,
-- DockMprisPill (tactile media controls), DockTrash (reactive trash can), Notifications & Power.

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local clients = if Zenith.Services and Zenith.Services.Clients then Zenith.Services.Clients() else {}
local active_win = if Zenith.Services and Zenith.Services.ActiveWindow then Zenith.Services.ActiveWindow() else nil

local dock_h = Store.get("dockHeight") or 52
local show_mpris = Store.get("dockShowMpris") ~= false
local show_trash = Store.get("dockShowTrash") or false
local show_utilities = Store.get("dockShowUtilities") ~= false
local blur_glass = Store.get("dockBlurGlass") ~= false
local auto_hide_enabled = Store.get("dockAutoHide") ~= false

-- ── 1. Sincronização Dinâmica com Hyprland gaps_out ──
local gaps_service = if Zenith.Services and Zenith.Services.HyprlandGaps then Zenith.Services.HyprlandGaps() else nil
local hypr_gaps_out = if gaps_service and gaps_service.gaps_out ~= nil then gaps_service.gaps_out
    elseif gaps_service and gaps_service.outer ~= nil then gaps_service.outer
    else nil

local default_margin_bottom = 12
local dock_margin_bottom = if hypr_gaps_out and hypr_gaps_out > 0 then hypr_gaps_out else (Store.get("dockMarginBottom") or default_margin_bottom)

-- ── 2. Lógica de Auto-Hide Inteligente (Detecção de Janelas Sobrepostas) ──
local function check_dock_collision(): boolean
    if not auto_hide_enabled then
        return false
    end

    local screen = if Zenith.Services and Zenith.Services.Screen then Zenith.Services.Screen() else nil
    local screen_h = if screen and screen.height and screen.height > 0 then screen.height else 1080
    local screen_w = if screen and screen.width and screen.width > 0 then screen.width else 1920

    local ws_info = if Zenith.Services and Zenith.Services.Workspaces then Zenith.Services.Workspaces() else nil
    local active_ws = if ws_info and ws_info.active ~= nil then ws_info.active else 1

    local expected_dock_h = dock_h + dock_margin_bottom + 20
    local dock_top = screen_h - expected_dock_h

    if clients then
        for _, c in ipairs(clients) do
            local ws_id = c.workspace_id or (c.workspace and c.workspace.id) or c.workspace
            local ws_name = c.workspace_name or ""
            local is_special = string.find(string.lower(ws_name), "special") ~= nil

            if not is_special and ws_id == active_ws then
                if c.fullscreen == true then
                    return true
                end

                local is_floating = c.floating == true
                local win_x = c.x or (c.at and c.at[1]) or 0
                local win_y = c.y or (c.at and c.at[2]) or 0
                local win_w = c.width or (c.size and c.size[1]) or 0
                local win_h = c.height or (c.size and c.size[2]) or 0

                if not is_floating then
                    return true
                else
                    local win_bottom = win_y + win_h
                    local win_right = win_x + win_w
                    local overlap_x = win_x < screen_w and win_right > 0
                    if win_bottom >= dock_top and win_y < screen_h and overlap_x then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local is_auto_hidden = check_dock_collision()

-- ── 3. Curva Suave de Magnificação macOS-like & Física Spring ──
local function calculate_zoom(dist: number, max_scale: number?, sigma: number?): (number, number)
    local peak = max_scale or 1.38
    local s = sigma or 1.15
    local target_scale = 1.0

    if dist <= 3 then
        target_scale = 1.0 + (peak - 1.0) * math.exp(-(dist * dist) / (2.0 * s * s))
    end

    local final_scale = target_scale
    if Zenith.Spring then
        local anim = Zenith.Spring(1.0, target_scale, 240, 18)
        if anim and anim.target then
            final_scale = anim.target
        end
    end

    local rise_offset = math.round((final_scale - 1.0) * 16)
    return final_scale, rise_offset
end

local function is_client_focused(client: any?, class_name: string?): boolean
    if client and client.focused == true then
        return true
    end
    if active_win and active_win.class and class_name then
        local pat = string.lower(class_name)
        local act_cls = string.lower(active_win.class)
        if string.find(act_cls, pat) or string.find(pat, act_cls) then
            return true
        end
    end
    return false
end

-- Pinned applications (Terminal, Navegador, Editor de Código, Gerenciador de Arquivos, Spotify, Discord)
local DEFAULT_PINNED_APPS = {
    { icon = "", name = "Terminal", class = "foot", exec = "foot" },
    { icon = "󰈹", name = "Navegador", class = "brave", exec = "brave" },
    { icon = "󰨞", name = "Editor de Código", class = "code", exec = "code" },
    { icon = "󰉋", name = "Gerenciador de Arquivos", class = "thunar", exec = "thunar" },
    { icon = "󰓇", name = "Spotify", class = "spotify", exec = "spotify" },
    { icon = "󰭹", name = "Discord", class = "vesktop", exec = "vesktop" },
}

local function load_pinned_apps(): { any }
    if Zenith.Storage and Zenith.Storage.get then
        local stored = Zenith.Storage.get("dock_pinned_apps", nil)
        if stored and type(stored) == "table" and #stored > 0 then
            return stored
        end
    end
    return DEFAULT_PINNED_APPS
end

local pinned_apps = load_pinned_apps()

local function is_pinned(class_name: string?): boolean
    local pat = string.lower(class_name or "")
    if pat == "" then return false end
    for _, pin in ipairs(pinned_apps) do
        local pin_cls = string.lower(pin.class or "")
        if pin_cls ~= "" and (string.find(pat, pin_cls) or string.find(pin_cls, pat)) then
            return true
        end
    end
    return false
end

local function toggle_pin(class_name: string, app_info: { icon: string?, name: string?, class: string, exec: string? })
    local current_pins = load_pinned_apps()
    local is_currently_pinned = false
    local new_pins = {}
    local lower_target = string.lower(class_name)

    for _, pin in ipairs(current_pins) do
        if string.lower(pin.class or "") == lower_target then
            is_currently_pinned = true
        else
            table.insert(new_pins, pin)
        end
    end

    if not is_currently_pinned then
        table.insert(new_pins, {
            icon = app_info.icon or "",
            name = app_info.name or app_info.class,
            class = app_info.class,
            exec = app_info.exec or app_info.class,
        })
    end

    if Zenith.Storage and Zenith.Storage.set then
        Zenith.Storage.set("dock_pinned_apps", new_pins)
        Zenith.Storage.set("dock_context_app", "none")
    end
end

-- Active context menu tracking (opened via right click)
local active_context_app = ""
if Zenith.Storage and Zenith.Storage.get then
    local stored_ctx = Zenith.Storage.get("dock_context_app", "")
    if stored_ctx and stored_ctx ~= "none" and stored_ctx ~= "nil" then
        active_context_app = string.lower(tostring(stored_ctx))
    end
end

local function get_app_clients(class_pattern: string): { any }
    local pat = string.lower(class_pattern)
    local matches = {}
    if clients then
        for _, c in ipairs(clients) do
            local c_class = string.lower(c.class or "")
            local c_init = string.lower(c.initial_class or "")
            if (c_class ~= "" and string.find(c_class, pat)) or (c_init ~= "" and string.find(c_init, pat)) then
                table.insert(matches, c)
            end
        end
    end
    return matches
end

local function check_app_clients_focus(app_clients: { any }, class_name: string): (boolean, any?, number)
    for idx, c in ipairs(app_clients) do
        if is_client_focused(c, class_name) then
            return true, c, idx
        end
    end
    return false, nil, 0
end

local function build_indicator(is_running: boolean, is_focused: boolean, count: number)
    if not is_running or count == 0 then
        return Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.rgba(0, 0, 0, 0),
        })
    end

    if is_focused then
        -- Focused: active pill indicator (parity with DockItem.qml width 16)
        return Zenith.Box({
            width = 16,
            height = 3.5,
            border_radius = 2,
            background = theme.primary,
        })
    elseif count > 1 then
        -- Multi-client: small grouped dots (up to 3 dots, parity with DockItem.qml)
        local dots = {}
        local dot_count = math.min(count, 3)
        for i = 1, dot_count do
            table.insert(dots, Zenith.Box({
                width = 4,
                height = 3,
                border_radius = 1.5,
                background = Zenith.hex(theme.primary, 190),
            }))
        end
        return Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "center",
            gap = 3,
            height = 4,
            children = dots,
        })
    else
        -- Single running client: single dot
        return Zenith.Box({
            width = 6,
            height = 3,
            border_radius = 1.5,
            background = Zenith.hex(theme.on_surface, 160),
        })
    end
end

local function get_click_action(
    is_running: boolean,
    is_focused: boolean,
    app_clients: { any },
    focused_idx: number,
    exec: string?,
    class_name: string,
    name: string
): string
    if not is_running or #app_clients == 0 then
        return "launch:" .. (exec or class_name or name)
    end

    local count = #app_clients
    if is_focused then
        if count > 1 then
            -- Multiple windows: cycle/alternate to NEXT active window
            local next_idx = (focused_idx % count) + 1
            local next_c = app_clients[next_idx]
            if next_c and next_c.address then
                return "focus:" .. next_c.address
            else
                return "window:toggle_minimize:" .. app_clients[1].address
            end
        else
            -- Single window currently focused: MINIMIZE
            local c = app_clients[1]
            return "window:toggle_minimize:" .. (c.address or "")
        end
    else
        -- Running but not currently focused: focus / restore window
        local target_c = app_clients[1]
        return "window:toggle_minimize:" .. (target_c.address or "")
    end
end

-- Render individual app capsule item with multi-client indicators & context menu drawer
local function DockItem(
    icon: string,
    name: string,
    class_name: string,
    is_running: boolean,
    app_clients: { any },
    focused_client: any?,
    focused_idx: number,
    exec: string?,
    is_focused: boolean?,
    scale: number?,
    rise_offset: number?,
    is_pin: boolean?
)
    local s = scale or 1.0
    local rise = rise_offset or 0
    local is_foc = is_focused == true
    local is_pinned_item = is_pin ~= false
    local count = #app_clients
    local target_client = if focused_client then focused_client else (if count > 0 then app_clients[1] else nil)

    local is_context_open = (active_context_app ~= "" and active_context_app == string.lower(class_name))

    if is_context_open then
        -- Context Menu Drawer (Port parity with DockContextMenu.qml)
        local context_items = {}

        -- App Identity Header
        table.insert(context_items, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            padding = { x = 4, y = 2 },
            children = {
                Zenith.Text({
                    text = icon,
                    font_size = 17,
                    color = theme.primary,
                }),
                Zenith.Text({
                    text = name,
                    font_size = 12,
                    font_weight = "bold",
                    color = theme.on_surface,
                }),
            }
        }))

        -- Divider
        table.insert(context_items, Zenith.Box({
            width = 1,
            height = 20,
            background = Zenith.hex(theme.outline, 45),
        }))

        -- 1. "Nova Janela" (lança exec correspondente)
        local new_win_action = "launch:" .. (exec or class_name)
        table.insert(context_items, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 4,
            padding = { x = 8, y = 4 },
            border_radius = 8,
            background = Zenith.hex(theme.surface_container, 180),
            tooltip = "Nova Janela",
            on_click = new_win_action,
            children = {
                Zenith.Text({ text = "󰐕", font_size = 13, color = theme.primary }),
                Zenith.Text({ text = "Nova Janela", font_size = 11, color = theme.on_surface }),
            }
        }))

        -- 2. "Fechar Janela" (hyprctl dispatch closewindow address:...)
        if is_running and target_client and target_client.address then
            local close_action = "cmd:hyprctl dispatch closewindow address:" .. target_client.address .. " &"
            table.insert(context_items, Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 4,
                padding = { x = 8, y = 4 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 180),
                tooltip = "Fechar Janela (" .. target_client.address .. ")",
                on_click = close_action,
                children = {
                    Zenith.Text({ text = "󰅖", font_size = 13, color = Zenith.hex(theme.error or "#f38ba8") }),
                    Zenith.Text({ text = "Fechar Janela", font_size = 11, color = Zenith.hex(theme.error or "#f38ba8") }),
                }
            }))
        end

        -- 3. "Fixar na Dock" / "Desafixar da Dock" (atualizar lista de pinned_apps)
        table.insert(context_items, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 4,
            padding = { x = 8, y = 4 },
            border_radius = 8,
            background = Zenith.hex(theme.surface_container, 180),
            tooltip = if is_pinned_item then "Desafixar da Dock" else "Fixar na Dock",
            on_click = function()
                toggle_pin(class_name, {
                    icon = icon,
                    name = name,
                    class = class_name,
                    exec = exec,
                })
            end,
            children = {
                Zenith.Text({
                    text = if is_pinned_item then "󰤰" else "󰤱",
                    font_size = 13,
                    color = theme.on_surface,
                }),
                Zenith.Text({
                    text = if is_pinned_item then "Desafixar da Dock" else "Fixar na Dock",
                    font_size = 11,
                    color = theme.on_surface,
                }),
            }
        }))

        -- Botão Fechar Menu de Contexto (✕)
        table.insert(context_items, Zenith.Box({
            padding = { x = 6, y = 4 },
            border_radius = 8,
            tooltip = "Fechar Menu",
            on_click = "storage:set:dock_context_app:none",
            children = {
                Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.outline) }),
            }
        }))

        return Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "center",
            padding = { x = 8, y = 3 },
            gap = 6,
            border_radius = 16,
            background = Zenith.hex(theme.surface_container_highest or theme.surface_container, 235),
            border_width = 1,
            border_color = Zenith.hex(theme.primary, 130),
            children = context_items,
        })
    end

    -- Normal dock item capsule
    local click_action = get_click_action(is_running, is_foc, app_clients, focused_idx, exec, class_name, name)
    local toggle_context_action = if is_context_open
        then "storage:set:dock_context_app:none"
        else ("storage:set:dock_context_app:" .. class_name)

    local f_size = math.round(20 * s)
    local pad_x = math.round(11 * s)
    local pad_y = math.round(4 * s)
    local radius = math.round(14 * s)

    local bg = if is_foc then Zenith.hex(theme.primary, 48)
        elseif is_running then Zenith.hex(theme.surface_container_high or theme.surface_container, 130)
        else Zenith.rgba(255, 255, 255, 0)

    local border_color = if is_foc then Zenith.hex(theme.primary, 110)
        elseif is_running then Zenith.hex(theme.outline_variant or theme.outline, 50)
        else Zenith.rgba(0, 0, 0, 0)

    local icon_color = if is_foc then theme.primary
        elseif is_running then theme.primary
        else theme.on_surface

    local top_pad = math.max(1, pad_y + rise)
    local bot_pad = math.max(1, pad_y - math.floor(rise / 2))

    local item_tooltip = name
    if is_running and target_client and target_client.title and #target_client.title > 0 then
        if count > 1 then
            item_tooltip = string.format("%s (%d janelas) • %s", name, count, target_client.title)
        else
            item_tooltip = name .. " • " .. target_client.title
        end
    elseif count > 1 then
        item_tooltip = string.format("%s (%d janelas)", name, count)
    end

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { top = top_pad, bottom = bot_pad, left = pad_x, right = pad_x },
        border_radius = radius,
        background = bg,
        border_color = border_color,
        border_width = if is_foc then 1.5 else (if is_running then 1 else 0),
        tooltip = item_tooltip,
        on_click = click_action,
        on_right_click = toggle_context_action,
        children = {
            Zenith.Text({
                text = icon,
                font_size = f_size,
                color = icon_color,
            }),
            build_indicator(is_running, is_foc, count),
        }
    })
end

-- ── 1. DockUtilities Component (Quick Tools: Terminal Rápido & Captura de Tela) ──
local function DockUtilities(theme_ref: any)
    local utils = {
        {
            id = "quake",
            icon = "",
            name = "Terminal Rápido",
            color = theme_ref.primary,
            click = "dispatch:togglespecialworkspace:quick-term",
            right_click = "cmd:foot &",
            tooltip = "Terminal Rápido (Drop-down)\n• Clique: Alternar workspace quick-term\n• Botão Direito: Novo Terminal",
        },
        {
            id = "screenshot",
            icon = "",
            name = "Captura de Tela",
            color = theme_ref.tertiary or "#89dceb",
            click = "screenshot:area",
            right_click = "screenshot:full",
            tooltip = "Captura de Tela\n• Clique: Selecionar Região\n• Botão Direito: Tela Cheia",
        },
        {
            id = "colorpicker",
            icon = "",
            name = "Pipeta de Cores",
            color = theme_ref.secondary or "#cba6f7",
            click = "cmd:hyprpicker -a -f hex &",
            right_click = nil,
            tooltip = "Pipeta de Cores (Hyprpicker)\n• Clique: Capturar cor HEX na tela",
        },
    }

    local items = {}
    for _, u in ipairs(utils) do
        table.insert(items, Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            padding = { x = 9, y = 4 },
            border_radius = 14,
            background = Zenith.hex(theme_ref.surface_container_high or theme_ref.surface_container, 80),
            tooltip = u.tooltip,
            on_click = u.click,
            on_right_click = u.right_click,
            children = {
                Zenith.Text({
                    text = u.icon,
                    font_size = 18,
                    color = u.color,
                }),
                Zenith.Text({
                    text = " ",
                    font_size = 6,
                    color = Zenith.hex("#00000000"),
                }),
            }
        }))
    end

    return items
end

-- ── 2. DockMprisPill Component (Compact media player capsule with scrolling info & tactile controls) ──
local function DockMprisPill(theme_ref: any)
    local media = Zenith.Services.Media()
    local has_media = media ~= nil 
        and media.is_available ~= false 
        and media.status ~= "Stopped" 
        and media.title ~= nil 
        and #media.title > 0

    if not has_media then
        -- Quando inativo, mantém atalho compacto e discreto para o painel de mídia
        return Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            padding = { x = 11, y = 4 },
            border_radius = 14,
            background = Zenith.hex(theme_ref.surface_container_high or theme_ref.surface_container, 80),
            tooltip = "Controles de Mídia\n• Clique: Abrir painel MPRIS",
            on_click = "popup:toggle:MediaPopup",
            children = {
                Zenith.Text({
                    text = "󰎆",
                    font_size = 18,
                    color = theme_ref.primary,
                }),
                Zenith.Text({
                    text = " ",
                    font_size = 6,
                    color = Zenith.rgba(0, 0, 0, 0),
                }),
            }
        })
    end

    local is_playing = media.status == "Playing"
    local raw_title = media.title or "Mídia"
    local raw_artist = if media.artist and #media.artist > 0 then media.artist else (media.player_name or "Desconhecido")

    -- Scroll / truncamento suave para visual elegante na dock
    local title_len = #raw_title
    local display_title = if title_len > 18 then raw_title:sub(1, 16) .. "…" else raw_title
    local artist_len = #raw_artist
    local display_artist = if artist_len > 15 then raw_artist:sub(1, 13) .. "…" else raw_artist

    local art_url = media.art_url or media.album_art or ""
    local album_art_box = nil
    if #art_url > 0 then
        album_art_box = Zenith.Box({
            width = 30,
            height = 30,
            border_radius = 8,
            children = {
                Zenith.Image({
                    src = art_url,
                    width = 30,
                    height = 30,
                    border_radius = 8,
                }),
            }
        })
    else
        album_art_box = Zenith.Box({
            width = 30,
            height = 30,
            border_radius = 8,
            background = Zenith.hex(theme_ref.surface_container or "#313244", 200),
            align_items = "center",
            justify_content = "center",
            children = {
                Zenith.Text({
                    text = "󰎆",
                    font_size = 15,
                    color = theme_ref.primary,
                }),
            }
        })
    end

    -- Barra fina de progresso na base se duração estiver disponível (DockMprisPill.qml line 68)
    local progress_bar = nil
    local total_len = media.length or 0
    local cur_pos = tonumber(Zenith.Storage and Zenith.Storage.get and Zenith.Storage.get("media_current_pos", 0)) or 0
    if total_len > 0 and cur_pos > 0 then
        local ratio = math.clamp(cur_pos / total_len, 0.0, 1.0)
        local progress_width = math.max(2, math.floor(ratio * 110))
        progress_bar = Zenith.Box({
            width = 110,
            height = 2,
            border_radius = 1,
            background = Zenith.hex(theme_ref.outline_variant or theme_ref.outline, 45),
            align_items = "flex-start",
            children = {
                Zenith.Box({
                    width = progress_width,
                    height = 2,
                    border_radius = 1,
                    background = theme_ref.primary,
                    children = {},
                })
            }
        })
    end

    local track_info_children = {
        Zenith.Text({
            text = display_title,
            font_size = 11,
            font_weight = "bold",
            color = theme_ref.on_surface,
        }),
        Zenith.Text({
            text = display_artist,
            font_size = 10,
            color = Zenith.hex(theme_ref.on_surface_variant or theme_ref.outline, 210),
        }),
    }
    if progress_bar then
        table.insert(track_info_children, progress_bar)
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        padding = { x = 8, y = 4 },
        gap = 8,
        border_radius = 16,
        background = Zenith.hex(theme_ref.surface_container_high or theme_ref.surface_container, 140),
        border_width = 1,
        border_color = Zenith.hex(theme_ref.outline_variant or theme_ref.outline, 45),
        tooltip = string.format("Mídia • %s - %s\n• Clique: Abrir Controles\n• Scroll: Alternar Faixas", raw_title, raw_artist),
        on_click = "popup:toggle:MediaPopup",
        on_scroll_up = "media:next",
        on_scroll_down = "media:previous",
        children = {
            album_art_box,
            Zenith.Box({
                direction = "column",
                justify_content = "center",
                gap = 1,
                children = track_info_children,
            }),
            -- Botões táteis de controle de mídia (Previous, Play/Pause, Next)
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 2,
                children = {
                    Zenith.Box({
                        align_items = "center",
                        justify_content = "center",
                        padding = { x = 4, y = 4 },
                        border_radius = 8,
                        tooltip = "Faixa Anterior",
                        on_click = "media:previous",
                        children = {
                            Zenith.Text({
                                text = "󰒮",
                                font_size = 13,
                                color = theme_ref.on_surface,
                            }),
                        }
                    }),
                    Zenith.Box({
                        align_items = "center",
                        justify_content = "center",
                        padding = { x = 6, y = 4 },
                        border_radius = 10,
                        background = Zenith.hex(theme_ref.primary, 35),
                        tooltip = if is_playing then "Pausar" else "Reproduzir",
                        on_click = "media:play-pause",
                        children = {
                            Zenith.Text({
                                text = if is_playing then "󰏤" else "󰐊",
                                font_size = 14,
                                color = theme_ref.primary,
                            }),
                        }
                    }),
                    Zenith.Box({
                        align_items = "center",
                        justify_content = "center",
                        padding = { x = 4, y = 4 },
                        border_radius = 8,
                        tooltip = "Próxima Faixa",
                        on_click = "media:next",
                        children = {
                            Zenith.Text({
                                text = "󰒭",
                                font_size = 13,
                                color = theme_ref.on_surface,
                            }),
                        }
                    }),
                }
            })
        }
    })
end

-- ── 3. DockTrash Component (Reactive trash icon with count badge & empty/open actions) ──
local function DockTrash(theme_ref: any)
    local trash_count = tonumber(Zenith.Storage and Zenith.Storage.get and Zenith.Storage.get("trash_count", nil)) or 0
    local is_empty = trash_count == 0

    local icon = if is_empty then "󰩹" else "󰩺"
    local icon_color = if is_empty then Zenith.hex(theme_ref.outline, 160) else Zenith.hex(theme_ref.error or "#f38ba8")
    local tooltip_text = if is_empty
        then "Lixeira (Vazia)\n• Clique: Abrir pasta da lixeira"
        else string.format("Lixeira (%d %s)\n• Clique: Abrir pasta\n• Botão Direito: Esvaziar lixeira", trash_count, if trash_count == 1 then "item" else "itens")

    local empty_action = "cmd:trash-empty -f 2>/dev/null || (trash_dir=\"${XDG_DATA_HOME:-$HOME/.local/share}/Trash\"; rm -rf \"$trash_dir\"/files/* \"$trash_dir\"/info/* 2>/dev/null) ; zenith-shell --dispatch storage:set:trash_count:0 2>/dev/null &"
    local open_action = "cmd:xdg-open trash:/// 2>/dev/null || thunar trash:/// &"

    local indicator_box = nil
    if not is_empty then
        indicator_box = Zenith.Box({
            padding = { x = 4, y = 1 },
            border_radius = 6,
            background = Zenith.hex(theme_ref.error or "#f38ba8"),
            children = {
                Zenith.Text({
                    text = if trash_count > 99 then "99+" else tostring(trash_count),
                    font_size = 8,
                    font_weight = "bold",
                    color = theme_ref.on_error or "#ffffff",
                }),
            }
        })
    else
        indicator_box = Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.rgba(0, 0, 0, 0),
        })
    end

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 11, y = 4 },
        border_radius = 14,
        background = Zenith.hex(theme_ref.surface_container_high or theme_ref.surface_container, 80),
        tooltip = tooltip_text,
        on_click = open_action,
        on_right_click = empty_action,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 18,
                color = icon_color,
            }),
            indicator_box,
        }
    })
end

local dock_children = {}

-- 1. App Launcher shortcut at left (NixOS icon )
table.insert(dock_children, Zenith.Box({
    direction = "column",
    align_items = "center",
    justify_content = "center",
    padding = { x = 11, y = 4 },
    border_radius = 14,
    background = Zenith.hex(theme.surface_container_high or theme.surface_container, 110),
    tooltip = "Abrir Launcher (Super)",
    on_click = "popup:toggle:Launcher",
    children = {
        Zenith.Text({
            text = "",
            font_size = 19,
            color = theme.primary,
        }),
        Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.hex("#00000000"),
        }),
    }
}))

-- 2. Quick Utilities Section (Quake Terminal, Screenshot, Color Picker)
if show_utilities then
    for _, u_item in ipairs(DockUtilities(theme)) do
        table.insert(dock_children, u_item)
    end
end

-- Subtle separator after Utilities / Launcher
table.insert(dock_children, Zenith.Box({
    width = 1,
    height = 28,
    background = Zenith.hex(theme.outline_variant or theme.outline, 45),
    margin = { x = 4, y = 0 },
    children = {},
}))

-- 3. Pinned Apps & Dynamic Unpinned Active Clients with Spring Magnification
type AppSlot = {
    is_pinned: boolean,
    icon: string,
    name: string,
    class_name: string,
    is_running: boolean,
    is_focused: boolean,
    focused_client: any?,
    focused_idx: number,
    app_clients: { any },
    exec: string?,
}

local app_slots: { AppSlot } = {}

-- Populate Pinned Apps
for _, pin in ipairs(pinned_apps) do
    local app_clients = get_app_clients(pin.class)
    local is_running = #app_clients > 0
    local is_foc, foc_client, foc_idx = check_app_clients_focus(app_clients, pin.class)
    table.insert(app_slots, {
        is_pinned = true,
        icon = pin.icon,
        name = pin.name,
        class_name = pin.class,
        is_running = is_running,
        is_focused = is_foc,
        focused_client = foc_client,
        focused_idx = foc_idx,
        app_clients = app_clients,
        exec = pin.exec,
    })
end

-- Populate Dynamic Unpinned Active Clients (Grouped by Application Class)
local unpinned_groups: { [string]: { class: string, clients: { any }, icon: string } } = {}
local unpinned_order: { string } = {}

for _, c in ipairs(clients) do
    local c_cls = c.class or ""
    if not is_pinned(c_cls) and c.title ~= "" and c_cls ~= "" then
        local lower_cls = string.lower(c_cls)
        if not unpinned_groups[lower_cls] then
            local icon = ""
            if string.find(lower_cls, "chrome") or string.find(lower_cls, "chromium") then icon = "󰈹"
            elseif string.find(lower_cls, "firefox") then icon = "󰈹"
            elseif string.find(lower_cls, "steam") then icon = "󰓓"
            elseif string.find(lower_cls, "obs") then icon = "󰑋"
            elseif string.find(lower_cls, "gimp") or string.find(lower_cls, "inkscape") or string.find(lower_cls, "blender") then icon = "󰽉"
            elseif string.find(lower_cls, "telegram") then icon = "󰀨"
            elseif string.find(lower_cls, "mpv") or string.find(lower_cls, "vlc") then icon = "󰕼"
            elseif string.find(lower_cls, "foot") or string.find(lower_cls, "kitty") or string.find(lower_cls, "alacritty") then icon = ""
            end

            unpinned_groups[lower_cls] = {
                class = c_cls,
                clients = {},
                icon = icon,
            }
            table.insert(unpinned_order, lower_cls)
        end
        table.insert(unpinned_groups[lower_cls].clients, c)
    end
end

local unpinned_start_slot = #app_slots + 1
local unpinned_count = 0
for _, lower_cls in ipairs(unpinned_order) do
    local group = unpinned_groups[lower_cls]
    local is_foc, foc_client, foc_idx = check_app_clients_focus(group.clients, group.class)
    table.insert(app_slots, {
        is_pinned = false,
        icon = group.icon,
        name = group.class,
        class_name = group.class,
        is_running = true,
        is_focused = is_foc,
        focused_client = foc_client,
        focused_idx = foc_idx,
        app_clients = group.clients,
        exec = group.class,
    })
    unpinned_count = unpinned_count + 1
end

-- Find focused app index for smooth Gaussian spring magnification
local focused_app_idx: number? = nil
for idx, slot in ipairs(app_slots) do
    if slot.is_focused then
        focused_app_idx = idx
        break
    end
end

-- Render Pinned Apps with macOS-like Magnification
for idx = 1, #pinned_apps do
    local slot = app_slots[idx]
    local dist = if focused_app_idx ~= nil then math.abs(idx - focused_app_idx) else 999
    local scale, rise = calculate_zoom(dist, 1.38, 1.15)
    table.insert(dock_children, DockItem(
        slot.icon,
        slot.name,
        slot.class_name,
        slot.is_running,
        slot.app_clients,
        slot.focused_client,
        slot.focused_idx,
        slot.exec,
        slot.is_focused,
        scale,
        rise,
        slot.is_pinned
    ))
end

-- Render Dynamic Unpinned Active Clients (with preceding separator if present)
if unpinned_count > 0 then
    table.insert(dock_children, Zenith.Box({
        width = 1,
        height = 28,
        background = Zenith.hex(theme.outline_variant or theme.outline, 45),
        margin = { x = 4, y = 0 },
        children = {},
    }))
    for idx = unpinned_start_slot, #app_slots do
        local slot = app_slots[idx]
        local dist = if focused_app_idx ~= nil then math.abs(idx - focused_app_idx) else 999
        local scale, rise = calculate_zoom(dist, 1.38, 1.15)
        table.insert(dock_children, DockItem(
            slot.icon,
            slot.name,
            slot.class_name,
            slot.is_running,
            slot.app_clients,
            slot.focused_client,
            slot.focused_idx,
            slot.exec,
            slot.is_focused,
            scale,
            rise,
            slot.is_pinned
        ))
    end
end

-- 5. Separator before right accessories
table.insert(dock_children, Zenith.Box({
    width = 1,
    height = 28,
    background = Zenith.hex(theme.outline_variant or theme.outline, 45),
    margin = { x = 4, y = 0 },
    children = {},
}))

-- 6. MPRIS Pill
if show_mpris then
    table.insert(dock_children, DockMprisPill(theme))
end

-- 7. Trash
if show_trash then
    table.insert(dock_children, DockTrash(theme))
end

-- 8. Separator before Notifications & Power Menu (if accessories present)
if show_mpris or show_trash then
    table.insert(dock_children, Zenith.Box({
        width = 1,
        height = 28,
        background = Zenith.hex(theme.outline_variant or theme.outline, 45),
        margin = { x = 4, y = 0 },
        children = {},
    }))
end

-- 9. Right Utility Section: Notifications + Power Menu
table.insert(dock_children, Zenith.Box({
    direction = "column",
    align_items = "center",
    justify_content = "center",
    padding = { x = 11, y = 4 },
    border_radius = 14,
    background = Zenith.hex(theme.surface_container_high or theme.surface_container, 80),
    tooltip = "Centro de Notificações",
    on_click = "popup:toggle:NotificationCenter",
    children = {
        Zenith.Text({
            text = "󰂚",
            font_size = 18,
            color = theme.on_surface,
        }),
        Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.hex("#00000000"),
        }),
    }
}))

table.insert(dock_children, Zenith.Box({
    direction = "column",
    align_items = "center",
    justify_content = "center",
    padding = { x = 11, y = 4 },
    border_radius = 14,
    background = Zenith.hex(theme.surface_container_high or theme.surface_container, 80),
    tooltip = "Menu de Energia",
    on_click = "popup:toggle:PowerMenu",
    children = {
        Zenith.Text({
            text = "󰐥",
            font_size = 18,
            color = Zenith.hex(theme.error or "#f38ba8"),
        }),
        Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.rgba(0, 0, 0, 0),
        }),
    }
}))

-- 10. Intelligent Auto-Hide: Reveal Strip when overlapping windows collide
if is_auto_hidden then
    return Zenith.Box({
        direction = "row",
        align_items = "flex-end",
        justify_content = "center",
        padding = { x = 0, top = 0, bottom = 4 },
        children = {
            Zenith.Box({
                width = 140,
                height = 4,
                border_radius = 2,
                background = Zenith.hex(theme.primary, 180),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
                border_width = 1,
                shadow = {
                    blur = 10,
                    color = Zenith.rgba(0, 0, 0, 130),
                    offset_y = 1,
                },
                tooltip = "Zenith Dock (Oculta por sobreposição - Clique para alternar)",
                on_click = "popup:toggle:dock",
                children = {},
            }),
        },
    })
end

local dock_bg = if blur_glass then Zenith.hex(theme.surface, 215) else Zenith.hex(theme.surface, 250)
local container_h = math.max(dock_h, math.round(dock_h * (if focused_app_idx ~= nil then 1.12 else 1.0)))

-- Root Dock Container: Bottom centered with dynamic gaps_out margin and glassmorphic pill
return Zenith.Box({
    direction = "row",
    align_items = "flex-end",
    justify_content = "center",
    padding = { x = 0, top = 0, bottom = dock_margin_bottom },
    children = {
        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = container_h,
            padding = { x = 14, y = 5 },
            gap = 6,
            border_radius = 24,
            background = dock_bg,
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            shadow = {
                blur = 22,
                color = Zenith.rgba(0, 0, 0, 160),
                offset_y = 6,
            },
            children = dock_children,
        }),
    },
})
