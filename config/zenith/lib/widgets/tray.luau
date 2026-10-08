--!strict
-- Zenith UI Kit - System Tray Widget (SNI / StatusNotifierItem)

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
    elseif s:find("network") or s:find("nm-") or s:find("wifi") then
        return "󰤨"
    elseif s:find("volume") or s:find("audio") then
        return "󰕾"
    elseif s:find("battery") then
        return "󰁹"
    elseif s:find("dropbox") or s:find("nextcloud") then
        return "󰃨"
    else
        return "󰐎"
    end
end

local function Tray()
    local theme = Zenith.Theme()
    local items = Zenith.Services.Tray()

    if #items == 0 then
        return Zenith.Box({
            direction = "row",
            children = {},
        })
    end

    local tray_children = {}
    for _, item in ipairs(items) do
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
