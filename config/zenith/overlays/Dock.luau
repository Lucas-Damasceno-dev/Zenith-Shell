--!strict
-- Zenith-Shell (Engine v2) - Floating Glassmorphic Wayland Bottom Dock
-- Parity 1:1 with Quickshell dock, Hyprland client tracking, spring physics and focus:<address>.

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local clients = Zenith.Services.Clients()

local dock_h = Store.get("dockHeight") or 56
local show_mpris = Store.get("dockShowMpris") ~= false
local show_trash = Store.get("dockShowTrash") or false
local blur_glass = Store.get("dockBlurGlass") ~= false

-- Pinned applications (Terminal, Navegador, Editor de Código, Gerenciador de Arquivos, Spotify, Discord)
local pinned_apps = {
    { icon = "", name = "Terminal", class = "foot", exec = "foot" },
    { icon = "󰈹", name = "Navegador", class = "brave", exec = "brave" },
    { icon = "󰨞", name = "Editor de Código", class = "code", exec = "code" },
    { icon = "󰉋", name = "Gerenciador de Arquivos", class = "thunar", exec = "thunar" },
    { icon = "󰓇", name = "Spotify", class = "spotify", exec = "spotify" },
    { icon = "󰭹", name = "Discord", class = "vesktop", exec = "vesktop" },
}

local function find_client(class_pattern: string)
    local pat = string.lower(class_pattern)
    for _, c in ipairs(clients) do
        local c_class = string.lower(c.class or "")
        local c_init = string.lower(c.initial_class or "")
        if string.find(c_class, pat) or string.find(c_init, pat) then
            return c
        end
    end
    return nil
end

local function is_pinned(class_name: string?): boolean
    local pat = string.lower(class_name or "")
    for _, pin in ipairs(pinned_apps) do
        if string.find(pat, string.lower(pin.class)) then
            return true
        end
    end
    return false
end

-- Render individual app capsule item
local function DockItem(icon: string, name: string, is_running: boolean, client: any?, exec: string?)
    local click_action = ""
    if is_running and client and client.address then
        -- Focus or toggle minimize window directly via Hyprland address
        click_action = "window:toggle_minimize:" .. client.address
    else
        click_action = "launch:" .. (exec or name)
    end

    local bg = is_running and Zenith.hex(theme.surface_container_high or theme.surface_container, 130) or Zenith.rgba(255, 255, 255, 0)
    local icon_color = is_running and theme.primary or theme.on_surface
    local indicator_color = is_running and theme.primary or Zenith.rgba(0, 0, 0, 0)

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 11, y = 4 },
        border_radius = 14,
        background = bg,
        tooltip = if is_running and client and client.title and #client.title > 0 then (name .. " • " .. client.title) else name,
        on_click = click_action,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 20,
                color = icon_color,
            }),
            -- Running indicator dot
            Zenith.Text({
                text = "●",
                font_size = 7,
                color = indicator_color,
            }),
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

-- Subtle separator
table.insert(dock_children, Zenith.Box({
    width = 1,
    height = 28,
    background = Zenith.hex(theme.outline_variant or theme.outline, 45),
    margin = { x = 4, y = 0 },
    children = {},
}))

-- 2. Pinned Apps (Terminal, Browser, Code, Files, Spotify, Discord)
for _, pin in ipairs(pinned_apps) do
    local client = find_client(pin.class)
    local is_running = client ~= nil
    table.insert(dock_children, DockItem(pin.icon, pin.name, is_running, client, pin.exec))
end

-- 3. Dynamic Unpinned Active Clients
local has_unpinned = false
for _, c in ipairs(clients) do
    if not is_pinned(c.class) and c.title ~= "" then
        if not has_unpinned then
            -- Separator before unpinned running apps
            table.insert(dock_children, Zenith.Box({
                width = 1,
                height = 28,
                background = Zenith.hex(theme.outline_variant or theme.outline, 45),
                margin = { x = 4, y = 0 },
                children = {},
            }))
            has_unpinned = true
        end

        local icon = ""
        local lower_cls = string.lower(c.class)
        if string.find(lower_cls, "chrome") or string.find(lower_cls, "chromium") then icon = "󰈹"
        elseif string.find(lower_cls, "firefox") then icon = "󰈹"
        elseif string.find(lower_cls, "steam") then icon = "󰓓"
        elseif string.find(lower_cls, "obs") then icon = "󰑋"
        elseif string.find(lower_cls, "gimp") or string.find(lower_cls, "inkscape") or string.find(lower_cls, "blender") then icon = "󰽉"
        elseif string.find(lower_cls, "telegram") then icon = "󰀨"
        elseif string.find(lower_cls, "mpv") or string.find(lower_cls, "vlc") then icon = "󰕼"
        end

        table.insert(dock_children, DockItem(icon, c.class, true, c, c.class))
    end
end

-- 4. Right Utility Section: Notifications + Power Menu
table.insert(dock_children, Zenith.Box({
    width = 1,
    height = 28,
    background = Zenith.hex(theme.outline_variant or theme.outline, 45),
    margin = { x = 4, y = 0 },
    children = {},
}))

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

-- 5. Optional Media Pill shortcut if enabled in Settings
if show_mpris then
    table.insert(dock_children, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 11, y = 4 },
        border_radius = 14,
        background = Zenith.hex(theme.surface_container_high or theme.surface_container, 80),
        tooltip = "Controles de Mídia",
        on_click = "popup:toggle:MediaPopup",
        children = {
            Zenith.Text({
                text = "󰎆",
                font_size = 18,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = " ",
                font_size = 6,
                color = Zenith.rgba(0, 0, 0, 0),
            }),
        }
    }))
end

-- 6. Optional Trash shortcut if enabled in Settings
if show_trash then
    table.insert(dock_children, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 11, y = 4 },
        border_radius = 14,
        background = Zenith.hex(theme.surface_container_high or theme.surface_container, 80),
        tooltip = "Lixeira",
        on_click = "launch:thunar trash:///",
        children = {
            Zenith.Text({
                text = "󰩹",
                font_size = 18,
                color = Zenith.hex(theme.outline),
            }),
            Zenith.Text({
                text = " ",
                font_size = 6,
                color = Zenith.rgba(0, 0, 0, 0),
            }),
        }
    }))
end

local dock_bg = if blur_glass then Zenith.hex(theme.surface, 215) else Zenith.hex(theme.surface, 250)

-- Root Dock Container: Bottom centered with 12px margin and glassmorphic pill
return Zenith.Box({
    direction = "row",
    align_items = "flex-end",
    justify_content = "center",
    padding = { x = 0, top = 0, bottom = 12 },
    children = {
        Zenith.Box({
            direction = "row",
            align_items = "center",
            height = dock_h,
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
