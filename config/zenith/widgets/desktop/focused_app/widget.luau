--!strict
-- Zenith-Shell: Focused App Widget
-- Active window title & application glyph with monitor tracking

local Pill = Zenith.import("widgets/shared/pill/init")
local Icons = Zenith.import("core/ui/icons")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

type FocusedAppProps = {
    reactive: boolean?,
    output: string?,
    on_click: string?,
}

local function sanitize_title(title: string?, app_name: string): string
    local t = title or ""
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if #t == 0 then
        return ""
    end

    local suffixes = {
        " %- Visual Studio Code",
        " — Visual Studio Code",
        " %- VSCodium",
        " — VSCodium",
        " — Mozilla Firefox",
        " %- Mozilla Firefox",
        " %- Brave",
        " — Brave",
        " %- Google Chrome",
        " — Google Chrome",
        " — Kitty",
        " %- Kitty",
        " — Ghostty",
        " %- Ghostty",
        " %- Obsidian",
        " — Obsidian",
        " %- Discord",
        " — Discord",
        " %- Spotify",
        " — Spotify",
        " %- Thunar",
        " — Thunar",
    }

    for _, suffix in ipairs(suffixes) do
        local start_idx = t:find(suffix .. "$")
        if start_idx then
            t = t:sub(1, start_idx - 1)
            t = t:gsub("%s+$", "")
            break
        end
    end

    if string.lower(t) == string.lower(app_name) or string.lower(t) == "terminal" then
        return ""
    end

    return t
end

local function truncate_title(title: string, max_len: number): string
    if #title <= max_len then
        return title
    end
    local cutoff = math.max(max_len - 1, 3)
    local sub = string.sub(title, 1, cutoff)
    sub = sub:gsub("%s+$", "")
    return sub .. "…"
end

local function FocusedApp(props: FocusedAppProps?)
    local theme = Theme.get()
    local active_win = Services.Hyprland.active_window()

    local screen = if Zenith.Services and Zenith.Services.Screen then Zenith.Services.Screen() else { width = 1366 }
    local screen_w = screen.width or 1366
    local is_narrow = screen_w < 1200
    local is_compact = screen_w < 1440
    local max_title_len = if is_narrow then 14 elseif is_compact then 22 elseif screen_w < 1920 then 34 else 46

    local cur_output = (props and props.output)
        or (Zenith.current_output and Zenith.current_output())
        or (Zenith.get_current_output and Zenith.get_current_output())
        or "default"

    local is_on_current_monitor = true
    if cur_output ~= "default" and active_win and active_win.class and #active_win.class > 0 then
        local snap = Services.Hyprland.workspaces()
        local ws_list = (snap and snap.workspaces) or {}
        local clients = Services.Hyprland.clients()
        for _, c in ipairs(clients) do
            if c.class == active_win.class and c.title == active_win.title then
                for _, ws in ipairs(ws_list) do
                    if ws.id == c.workspace_id and ws.monitor and ws.monitor ~= "" and ws.monitor ~= cur_output then
                        is_on_current_monitor = false
                        break
                    end
                end
                break
            end
        end
    end

    local has_client = active_win and active_win.class and #active_win.class > 0 and is_on_current_monitor

    local app_glyph = "󰘔"
    local app_name = "Zenith Shell"
    local sanitized_title = ""
    local tooltip = "Área de Trabalho • Nenhuma Janela Focada\n• Clique: Alternar Visão Geral (Overview)\n• Scroll: Alternar Workspaces"

    if has_client and active_win then
        app_glyph = Icons.for_app(active_win.class, active_win.title)
        local raw_cls = active_win.class or ""
        local part = raw_cls:match("([^.]+)$") or raw_cls
        app_name = if #part > 0 then (part:sub(1, 1):upper() .. part:sub(2)) else "App"
        sanitized_title = sanitize_title(active_win.title, app_name)

        local raw_full = (active_win.title and #active_win.title > 0 and active_win.title) or app_name
        tooltip = string.format("%s • %s\n• Clique: Focar / Maximizar Janela\n• Botão Direito: Alternar Overview / Flutuante\n• Scroll: Alternar Workspaces", app_name, raw_full)
    end

    local primary_click = (props and props.on_click)
        or if has_client then "dispatch:fullscreen:1" else "dispatch:togglespecialworkspace:overview"
    local secondary_click = "dispatch:togglespecialworkspace:overview"

    local children = {}

    table.insert(children, Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        cursor = "pointer",
        on_click = "dispatch:togglespecialworkspace:overview",
        children = {
            Zenith.Text({
                text = app_glyph,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            })
        }
    }))

    table.insert(children, Zenith.Box({
        direction = "row",
        align_items = "center",
        cursor = "pointer",
        on_click = primary_click,
        children = {
            Zenith.Text({
                text = app_name,
                font_size = 11,
                font_weight = if has_client then "bold" else "medium",
                color = Zenith.hex(theme.on_surface),
            })
        }
    }))

    if has_client and #sanitized_title > 0 and not is_narrow then
        local truncated = truncate_title(sanitized_title, max_title_len)
        table.insert(children, Zenith.Text({
            text = "›",
            font_size = 11,
            color = Zenith.hex(theme.outline_variant or theme.outline, 140),
        }))
        table.insert(children, Zenith.Box({
            direction = "row",
            align_items = "center",
            cursor = "pointer",
            on_click = primary_click,
            children = {
                Zenith.Text({
                    text = truncated,
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface_variant or theme.on_surface, 215),
                })
            }
        }))
    end

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { horizontal = if is_compact then 8 else 10, vertical = 2 },
        gap = 5,
        tooltip = tooltip,
        on_click = primary_click,
        on_right_click = secondary_click,
        on_scroll_up = "dispatch:workspace:m+1",
        on_scroll_down = "dispatch:workspace:m-1",
        children = children,
    })
end

return FocusedApp
