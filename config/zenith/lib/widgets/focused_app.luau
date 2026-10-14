--!strict
-- Zenith UI Kit - Focused App / Active Window Component (Quickshell Parity)
-- Matches FocusedApp.qml (Left bar placement with glyph resolver & title truncation)

local Pill = Zenith.import("widgets/pill")

local function resolve_app_icon(class: string?): string
    local s = string.lower(class or "")
    if s:find("terminal") or s:find("foot") or s:find("kitty") or s:find("alacritty") or s:find("ghostty") or s:find("wezterm") then
        return ""
    elseif s:find("firefox") or s:find("chrome") or s:find("brave") or s:find("zen") or s:find("chromium") or s:find("browser") then
        return "󰈹"
    elseif s:find("code") or s:find("vscodium") or s:find("cursor") or s:find("zed") or s:find("nvim") or s:find("editor") then
        return "󰨞"
    elseif s:find("thunar") or s:find("nautilus") or s:find("dolphin") or s:find("pcmanfm") or s:find("files") then
        return "󰉋"
    elseif s:find("discord") or s:find("vesktop") or s:find("telegram") or s:find("slack") or s:find("chat") then
        return "󰭹"
    elseif s:find("spotify") or s:find("ncspot") or s:find("music") then
        return "󰎆"
    elseif s:find("obs") or s:find("mpv") or s:find("vlc") or s:find("video") then
        return "󰕼"
    elseif s:find("steam") or s:find("lutris") or s:find("heroic") or s:find("game") then
        return ""
    elseif s:find("gimp") or s:find("inkscape") or s:find("blender") then
        return "󰽉"
    elseif s:find("settings") or s:find("control") or s:find("pavucontrol") then
        return "󰒓"
    else
        return ""
    end
end

local function FocusedApp(props: { reactive: boolean? }?)
    local theme = Zenith.Theme()
    local active_win = Zenith.Services.ActiveWindow()

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local is_narrow = screen_w < 1200
    local is_compact = screen_w < 1440
    local max_title_len = if is_narrow then 10 elseif is_compact then 18 elseif screen_w < 1920 then 28 else 40

    local app_glyph = "󰘔"
    local win_text = "Zenith Shell"
    local tooltip = "Área de Trabalho • Nenhuma Janela Focada"

    if active_win and active_win.class and #active_win.class > 0 then
        app_glyph = resolve_app_icon(active_win.class)
        local raw_title = active_win.title or active_win.class
        if #raw_title > max_title_len then
            win_text = string.sub(raw_title, 1, math.max(max_title_len - 2, 4)) .. ".."
        else
            win_text = raw_title
        end
        tooltip = (active_win.class or "App") .. " • " .. (active_win.title or active_win.class or "") .. "\n• Clique: Focar Janela\n• Botão Direito: Alternar Janela Flutuante\n• Scroll: Alternar Workspaces"
    end

    local is_reactive = if props and props.reactive ~= nil then props.reactive else true
    local title_binding = if is_reactive and Zenith.Signals and Zenith.Signals.ActiveWindow then Zenith.Signals.ActiveWindow else win_text

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { x = if is_compact then 8 else 10, y = 2 },
        gap = 5,
        tooltip = tooltip,
        on_click = "dispatch:focuswindow:current",
        on_right_click = "dispatch:togglefloating:active",
        on_scroll_up = "dispatch:workspace:e+1",
        on_scroll_down = "dispatch:workspace:e-1",
        children = {
            Zenith.Text({
                text = app_glyph,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = title_binding,
                font_size = 11,
                color = Zenith.hex(theme.on_surface),
            }),
        }
    })
end

return FocusedApp
