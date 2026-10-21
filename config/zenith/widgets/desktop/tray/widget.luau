--!strict
-- Zenith-Shell: System Tray Widget (SNI / StatusNotifierItem)

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

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

local function Tray()
    local theme = Theme.get()
    local items = Services.Tray.items()

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
        local srv = item.service or ""
        table.insert(tray_children, Zenith.Box({
            direction = "row",
            align_items = "center",
            justify_content = "center",
            height = 20,
            padding = { horizontal = 5, vertical = 1 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container_high or theme.surface_container, 90),
            tooltip = (item.title or item.id or "Bandeja") .. "\n• Clique: Ativar\n• Botão Direito: Menu de Contexto",
            on_click = item.action or ("tray:activate:" .. srv),
            on_right_click = "tray:context:" .. srv,
            on_scroll_up = "tray:scroll:" .. srv .. ":1",
            on_scroll_down = "tray:scroll:" .. srv .. ":-1",
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
        align_items = "center",
        height = 26,
        gap = 4,
        padding = { horizontal = 6, vertical = 2 },
        border_radius = 13,
        background = Zenith.hex(theme.surface_container, 120),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 45),
        border_width = 1,
        children = tray_children,
    })
end

return Tray
