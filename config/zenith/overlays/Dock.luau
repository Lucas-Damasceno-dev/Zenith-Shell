-- Dock: Floating Glassmorphic Wayland Bottom Dock (Caelestia / macOS Style)
-- Integrates with Hyprland client tracking, running window indicators, and launcher dispatch.

local theme = Zenith.Theme()
local clients = Zenith.Services.Clients()

-- Pinned applications configuration
local pinned_apps = {
    { icon = "", name = "Terminal", class = "kitty", exec = "kitty" },
    { icon = "󰈹", name = "Firefox", class = "firefox", exec = "firefox" },
    { icon = "󰨞", name = "VS Code", class = "code", exec = "code" },
    { icon = "󰉋", name = "Files", class = "nautilus", exec = "nautilus" },
    { icon = "󰭹", name = "Discord", class = "discord", exec = "discord" },
    { icon = "󰎆", name = "Spotify", class = "spotify", exec = "spotify" },
}

local function find_client(class_pattern)
    for _, c in ipairs(clients) do
        local c_class = string.lower(c.class or "")
        local c_init = string.lower(c.initial_class or "")
        local pat = string.lower(class_pattern)
        if string.find(c_class, pat) or string.find(c_init, pat) then
            return c
        end
    end
    return nil
end

local function is_pinned(class_name)
    local pat = string.lower(class_name or "")
    for _, pin in ipairs(pinned_apps) do
        if string.find(pat, string.lower(pin.class)) then
            return true
        end
    end
    return false
end

-- Render individual app capsule item
local function DockItem(icon, name, is_running, client, exec)
    local click_action = ""
    if is_running and client and client.address then
        click_action = "focus:" .. client.address
    else
        click_action = "cmd:" .. (exec or name) .. " &"
    end

    local bg = is_running and Zenith.hex("#ffffff12") or Zenith.hex("#ffffff00")
    local icon_color = is_running and theme.primary or theme.on_surface
    local indicator_color = is_running and theme.primary or Zenith.hex("#ffffff00")

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 10, y = 4 },
        border_radius = 12,
        background = bg,
        on_click = click_action,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 18,
                font_family = "JetBrainsMono Nerd Font",
                color = icon_color,
            }),
            -- Running indicator dot
            Zenith.Text({
                text = "●",
                font_size = 6,
                font_family = "JetBrainsMono Nerd Font",
                color = indicator_color,
            }),
        }
    })
end

local dock_children = {}

-- 1. App Launcher shortcut at left
table.insert(dock_children, Zenith.Box({
    direction = "column",
    align_items = "center",
    justify_content = "center",
    padding = { x = 10, y = 4 },
    border_radius = 12,
    background = Zenith.hex("#ffffff0c"),
    on_click = "cmd:zenith toggle Launcher &",
    children = {
        Zenith.Text({
            text = "󰀻",
            font_size = 18,
            font_family = "JetBrainsMono Nerd Font",
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
    background = theme.outline,
    margin = { x = 4, y = 0 },
    children = {},
}))

-- 2. Pinned Apps
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
                background = theme.outline,
                margin = { x = 4, y = 0 },
                children = {},
            }))
            has_unpinned = true
        end

        local icon = ""
        local lower_cls = string.lower(c.class)
        if string.find(lower_cls, "chrome") or string.find(lower_cls, "brave") then icon = "󰈹"
        elseif string.find(lower_cls, "steam") then icon = "󰓓"
        elseif string.find(lower_cls, "obs") then icon = "󰑋"
        elseif string.find(lower_cls, "gimp") or string.find(lower_cls, "inkscape") then icon = "󰽉"
        elseif string.find(lower_cls, "telegram") then icon = "󰀨"
        end

        table.insert(dock_children, DockItem(icon, c.class, true, c, c.class))
    end
end

-- 4. Right Utility Section
table.insert(dock_children, Zenith.Box({
    width = 1,
    height = 28,
    background = theme.outline,
    margin = { x = 4, y = 0 },
    children = {},
}))

table.insert(dock_children, Zenith.Box({
    direction = "column",
    align_items = "center",
    justify_content = "center",
    padding = { x = 10, y = 4 },
    border_radius = 12,
    background = Zenith.hex("#ffffff08"),
    on_click = "cmd:zenith toggle NotificationCenter &",
    children = {
        Zenith.Text({
            text = "󰂚",
            font_size = 17,
            font_family = "JetBrainsMono Nerd Font",
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
    padding = { x = 10, y = 4 },
    border_radius = 12,
    background = Zenith.hex("#ffffff08"),
    on_click = "cmd:zenith toggle PowerMenu &",
    children = {
        Zenith.Text({
            text = "󰐥",
            font_size = 17,
            font_family = "JetBrainsMono Nerd Font",
            color = Zenith.hex("#f38ba8"),
        }),
        Zenith.Text({
            text = " ",
            font_size = 6,
            color = Zenith.hex("#00000000"),
        }),
    }
}))

-- Root Dock Container with Soft Drop Shadow & Glass Background
return Zenith.Box({
    direction = "row",
    align_items = "center",
    justify_content = "center",
    padding = { x = 14, y = 5 },
    gap = 4,
    border_radius = 20,
    background = Zenith.hex("#181b22e8"),
    border_color = theme.outline,
    border_width = 1,
    shadow = {
        blur = 24,
        color = Zenith.hex("#00000099"),
        offset_y = 6,
    },
    children = dock_children,
})
