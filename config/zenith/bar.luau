--!strict
-- Zenith-Shell (Engine v2) - Declarative Top Bar Configuration
-- Floating glassmorphic desktop bar with 1:1 Quickshell parities & Matugen/Stylix theming

local theme = Zenith.Theme()

-- Import reusable UI kit components
local Launcher = Zenith.import("widgets/launcher")
local Workspaces = Zenith.import("widgets/workspaces")
local Clock = Zenith.import("widgets/clock")
local Hardware = Zenith.import("widgets/hardware")
local Cava = Zenith.import("widgets/cava")
local QuickStatus = Zenith.import("widgets/quick_status")
local Media = Zenith.import("widgets/media")
local Tray = Zenith.import("widgets/tray")

local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366, height = 768 }
local screen_w = screen.width or 1366

local is_compact = screen_w < 1440
local is_narrow = screen_w < 1200
local max_title_len = if is_narrow then 10 elseif is_compact then 18 elseif screen_w < 1920 then 28 else 40

local active_win = Zenith.Services.ActiveWindow()

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

local app_glyph = "󰘔"
local win_text = "Zenith Shell"
if active_win and active_win.class and #active_win.class > 0 then
    app_glyph = resolve_app_icon(active_win.class)
    local raw_title = active_win.title or active_win.class
    if #raw_title > max_title_len then
        win_text = string.sub(raw_title, 1, math.max(max_title_len - 2, 4)) .. ".."
    else
        win_text = raw_title
    end
end

-- 1. LEFT CLUSTER: Launcher (NixOS ) + Dynamic Hyprland Workspaces
local left_cluster_children = {
    Launcher({ text = "" }),
    Workspaces(),
}

-- 2. CENTER CLUSTER: Focused App Chip + MPRIS2 Media
local center_cluster_children = {
    Zenith.Box({
        direction = "row",
        align_items = "center",
        height = 26,
        gap = 5,
        padding = { x = if is_compact then 8 else 10, y = 2 },
        border_radius = 13,
        background = Zenith.hex(theme.surface_container, 130),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
        border_width = 1,
        tooltip = if active_win and active_win.title and #active_win.title > 0 then (active_win.class .. " • " .. active_win.title) else "Janela Ativa",
        on_click = "cmd:hyprctl dispatch focuswindow current &",
        children = {
            Zenith.Text({
                text = app_glyph,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = win_text,
                font_size = 11,
                color = Zenith.hex(theme.on_surface),
            }),
        }
    }),
    Media(),
}

-- 3. RIGHT CLUSTER: Snipping/REC + Hardware (CPU/RAM/Disk) + CAVA + Tray + QuickStatus + Clock
local right_cluster_children = {
    Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "center",
        height = 26,
        padding = { x = 7, y = 2 },
        border_radius = 13,
        background = Zenith.hex(theme.surface_container, 130),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
        border_width = 1,
        tooltip = "Captura de Tela (Região)",
        on_click = "screenshot:area",
        children = {
            Zenith.Text({
                text = "󰄀",
                font_size = 12,
                color = Zenith.hex(theme.on_surface),
            }),
        }
    }),
}

if Zenith.Services.IsRecording() then
    table.insert(right_cluster_children, Zenith.Box({
        direction = "row",
        align_items = "center",
        height = 26,
        padding = { x = if is_compact then 7 else 9, y = 2 },
        border_radius = 13,
        background = Zenith.hex(theme.error or "#f38ba8", 50),
        border_color = Zenith.hex(theme.error or "#f38ba8", 120),
        border_width = 1,
        tooltip = "Gravando Tela • Clique para Interromper",
        on_click = "record:toggle",
        children = {
            Zenith.Text({
                text = "● REC",
                font_size = 11,
                color = Zenith.hex("#ffffff"),
            }),
        }
    }))
end

table.insert(right_cluster_children, Hardware())

local cava_widget = Cava({ bar_count = 8 })
if cava_widget then
    table.insert(right_cluster_children, cava_widget)
end

local tray_widget = Tray()
if tray_widget then
    table.insert(right_cluster_children, tray_widget)
end

table.insert(right_cluster_children, QuickStatus())
table.insert(right_cluster_children, Clock())

return Zenith.Box({
    direction = "row",
    height = 42,
    padding = { x = if is_compact then 10 else 16, y = 3 },
    background = Zenith.rgba(0, 0, 0, 0), -- Transparent wrapper for floating aesthetic
    children = {
        -- Floating Glassmorphic Pill Container
        Zenith.Box({
            direction = "row",
            align_items = "center",
            flex_grow = 1,
            height = 36,
            padding = { x = if is_compact then 6 else 8, y = 3 },
            gap = if is_compact then 4 else 6,
            border_radius = 18,
            background = Zenith.hex(theme.surface, 215), -- Matugen warm frosted glass with Kawase blur
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            shadow = {
                color = Zenith.rgba(0, 0, 0, 160),
                blur = 18,
                offset_x = 0,
                offset_y = 4,
            },
            children = {
                -- 1. LEFT CLUSTER: Launcher + Dynamic Workspaces
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 4 else 5,
                    children = left_cluster_children,
                }),

                -- Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 2. CENTER CLUSTER: Focused App Chip + MPRIS2 Media
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 4 else 5,
                    children = center_cluster_children,
                }),

                -- Spacer
                Zenith.Box({ flex_grow = 1 }),

                -- 3. RIGHT CLUSTER: Snipping + Telemetry (Hardware, CAVA, Tray) + Quick Status + Clock
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = if is_compact then 3 else 4,
                    children = right_cluster_children,
                }),
            }
        })
    }
})
