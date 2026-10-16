--!strict
-- Zenith UI Kit - Focused App / Active Window Component (Quickshell Parity)
-- Matches FocusedApp.qml (Left bar placement with glyph resolver, title truncation, overview toggle & focus/maximize)

local Pill = Zenith.import("widgets/pill")

local function resolve_app_icon_and_name(class: string?, initial_class: string?, title: string?): (string, string)
    local raw_cls = string.lower(class or initial_class or "")
    local raw_title = string.lower(title or "")
    local combined = string.format("%s %s", raw_cls, raw_title)

    -- Foot & Terminals
    if raw_cls:find("^foot") or combined:find("foot") then
        return "", "Foot"
    elseif raw_cls:find("kitty") or combined:find("kitty") then
        return "󰄛", "Kitty"
    elseif raw_cls:find("alacritty") or combined:find("alacritty") then
        return "", "Alacritty"
    elseif raw_cls:find("ghostty") or combined:find("ghostty") then
        return "󰊠", "Ghostty"
    elseif raw_cls:find("wezterm") or combined:find("wezterm") then
        return "", "WezTerm"
    elseif raw_cls:find("terminal") or combined:find("terminal") then
        return "", "Terminal"
    -- Browsers
    elseif raw_cls:find("brave") or combined:find("brave") then
        return "󰖟", "Brave"
    elseif raw_cls:find("firefox") or combined:find("firefox") then
        return "󰈹", "Firefox"
    elseif raw_cls:find("chrome") or combined:find("chrome") or raw_cls:find("chromium") then
        return "", "Chrome"
    elseif raw_cls:find("zen") or combined:find("zen%-browser") then
        return "󰈹", "Zen"
    -- Editors / IDEs
    elseif raw_cls:find("code") or raw_cls:find("vscode") or raw_cls:find("vscodium") or raw_cls:find("cursor") or combined:find("visual studio code") then
        return "󰨞", "VS Code"
    elseif raw_cls:find("zed") then
        return "󰨞", "Zed"
    elseif raw_cls:find("nvim") or raw_cls:find("neovim") or combined:find("nvim") then
        return "", "Neovim"
    elseif raw_cls:find("editor") then
        return "󰨞", "Editor"
    -- File Managers
    elseif raw_cls:find("thunar") or combined:find("thunar") then
        return "󰉋", "Thunar"
    elseif raw_cls:find("nautilus") or combined:find("nautilus") or raw_cls:find("files") then
        return "󰉋", "Files"
    elseif raw_cls:find("dolphin") or combined:find("dolphin") then
        return "󰉋", "Dolphin"
    elseif raw_cls:find("pcmanfm") then
        return "󰉋", "PCManFM"
    -- Communication / Social
    elseif raw_cls:find("discord") or raw_cls:find("vesktop") or combined:find("discord") then
        return "󰭹", "Discord"
    elseif raw_cls:find("telegram") or combined:find("telegram") then
        return "", "Telegram"
    elseif raw_cls:find("slack") or combined:find("slack") then
        return "󰒱", "Slack"
    -- Audio / Music
    elseif raw_cls:find("spotify") or combined:find("spotify") then
        return "󰎆", "Spotify"
    elseif raw_cls:find("ncspot") or combined:find("music") then
        return "󰎆", "Music"
    -- Video / Media
    elseif raw_cls:find("obs") or combined:find("obs%-studio") then
        return "󰕼", "OBS Studio"
    elseif raw_cls:find("mpv") or combined:find("mpv") then
        return "󰕼", "MPV"
    elseif raw_cls:find("vlc") or combined:find("vlc") then
        return "󰕼", "VLC"
    -- Gaming
    elseif raw_cls:find("steam") or combined:find("steam") then
        return "", "Steam"
    elseif raw_cls:find("lutris") or raw_cls:find("heroic") or combined:find("game") then
        return "", "Games"
    -- Creativity / Design
    elseif raw_cls:find("gimp") or combined:find("gimp") then
        return "󰽉", "GIMP"
    elseif raw_cls:find("inkscape") or combined:find("inkscape") then
        return "󰽉", "Inkscape"
    elseif raw_cls:find("blender") or combined:find("blender") then
        return "󰽉", "Blender"
    -- Note Taking / System
    elseif raw_cls:find("obsidian") or combined:find("obsidian") then
        return "󰠮", "Obsidian"
    elseif raw_cls:find("settings") or raw_cls:find("control") or raw_cls:find("pavucontrol") then
        return "󰒓", "Settings"
    elseif raw_cls:find("antigravity") or raw_cls:find("opencode") then
        return "󰘔", "Zenith"
    else
        local fallback_name = "App"
        if class and #class > 0 then
            local part = class:match("([^.]+)$") or class
            fallback_name = part:sub(1, 1):upper() .. part:sub(2)
        end
        return "", fallback_name
    end
end

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

local function FocusedApp(props: { reactive: boolean?, output: string?, on_click: string? }?)
    local theme = Zenith.Theme()
    local active_win = Zenith.Services.ActiveWindow()

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local is_narrow = screen_w < 1200
    local is_compact = screen_w < 1440
    local max_title_len = if is_narrow then 14 elseif is_compact then 22 elseif screen_w < 1920 then 34 else 46

    local cur_output = (props and props.output)
        or (Zenith.current_output and Zenith.current_output())
        or (Zenith.get_current_output and Zenith.get_current_output())
        or "default"

    -- Multi-monitor matching: verify active window monitor if available
    local is_on_current_monitor = true
    if cur_output ~= "default" and Zenith.Services.Workspaces and Zenith.Services.Clients and active_win and active_win.class and #active_win.class > 0 then
        local snap = Zenith.Services.Workspaces()
        local ws_list = (snap and snap.workspaces) or {}
        local clients = Zenith.Services.Clients()
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

    if has_client then
        local glyph, name = resolve_app_icon_and_name(active_win.class, nil, active_win.title)
        app_glyph = glyph
        app_name = name
        sanitized_title = sanitize_title(active_win.title, app_name)

        local raw_full = (active_win.title and #active_win.title > 0 and active_win.title) or app_name
        tooltip = string.format("%s • %s\n• Clique: Focar / Maximizar Janela\n• Botão Direito: Alternar Overview / Flutuante\n• Scroll: Alternar Workspaces", app_name, raw_full)
    end

    -- Click action: if window is active, click toggles maximize/focus; if on desktop, click toggles overview
    local primary_click = (props and props.on_click)
        or if has_client then "dispatch:fullscreen:1" else "dispatch:togglespecialworkspace:overview"
    local secondary_click = "dispatch:togglespecialworkspace:overview"

    local children = {}

    -- App Icon glyph (clicking icon triggers overview toggle)
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

    -- App Name label (clicking title triggers focus/maximize)
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

    -- Separator and Document Title (if active and not redundant)
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
        padding = { x = if is_compact then 8 else 10, y = 2 },
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
