--!strict
-- Zenith UI Kit - System Tray Widget (SNI / StatusNotifierItem)

local function is_system_item(id: string, icon_name: string, title: string, service: string): boolean
    local s = ((id or "") .. " " .. (icon_name or "") .. " " .. (title or "") .. " " .. (service or "")):lower()
    if s:find("nm%-applet") or s:find("networkmanager") or s:find("wifi") or s:find("network") then
        return true
    end
    if s:find("volume") or s:find("wireplumber") or s:find("pipewire") or s:find("audio") then
        return true
    end
    if s:find("battery") or s:find("upower") or s:find("power") then
        return true
    end
    return false
end

local function resolve_tray_icon(id: string, icon_name: string): string
    local s = (id .. " " .. icon_name):lower()
    if s:find("steam") then
        return "󰓓"
    elseif s:find("discord") or s:find("vesktop") then
        return "󰙯"
    elseif s:find("telegram") then
        return "󰔁"
    elseif s:find("obs") then
        return "󰑋"
    elseif s:find("spotify") then
        return "󰓃"
    elseif s:find("bluetooth") then
        return "󰂯"
    elseif s:find("dropbox") or s:find("nextcloud") then
        return "󰃨"
    else
        return "󰐎"
    end
end

local function Tray()
    local theme = Zenith.Theme()
    local items = Zenith.Services.Tray and Zenith.Services.Tray() or {}

    local valid_items = {}
    for _, item in ipairs(items) do
        if not is_system_item(item.id or "", item.icon or "", item.title or "", item.service or "") then
            table.insert(valid_items, item)
        end
    end

    if #valid_items == 0 then
        return nil
    end

    local tray_children = {}
    for _, item in ipairs(valid_items) do
        local glyph = resolve_tray_icon(item.id or "", item.icon or "")
        table.insert(tray_children, Zenith.Box({
            direction = "row",
            padding = { x = 6, y = 2 },
            border_radius = 6,
            background = Zenith.rgba(255, 255, 255, 10),
            on_click = item.action or ("tray:activate:" .. (item.service or "")),
            children = {
                Zenith.Text({
                    text = glyph,
                    font_size = 12,
                    color = Zenith.hex(theme.on_surface),
                })
            }
        }))
    end

    return Zenith.Box({
        direction = "row",
        gap = 4,
        padding = { x = 6, y = 2 },
        border_radius = 8,
        background = Zenith.rgba(26, 27, 38, 120),
        border_color = Zenith.rgba(255, 255, 255, 15),
        border_width = 1,
        children = tray_children,
    })
end

return Tray
