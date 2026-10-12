--!strict
-- Zenith UI Kit - Media Pill Component (MPRIS2 / Caelestia style)

local Pill = Zenith.import("widgets/pill")

local function MediaWidget()
    local theme = Zenith.Theme()
    local media = Zenith.Services.Media()

    if not media.is_available or media.status == "Stopped" then
        return Pill({
            height = 26,
            border_radius = 13,
            padding = { x = 8, y = 2 },
            icon = "󰎆",
            icon_size = 12,
            icon_color = Zenith.hex(theme.on_surface_variant or theme.outline, 140),
            on_click = "popup:toggle:MediaPopup",
        })
    end

    local status_icon = if media.status == "Playing" then "󰐊" else "󰏤"
    local label = if #media.artist > 0 then
        string.format("%s - %s", media.artist, media.title)
    else
        media.title

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local max_len = if screen_w < 1200 then 10 elseif screen_w < 1440 then 13 elseif screen_w < 1920 then 20 else 32

    if #label > max_len then
        label = label:sub(1, max_len - 2) .. ".."
    end

    local spectrum = Zenith.Services.Spectrum(4)
    local spectrum_bars = {}
    for _, val in ipairs(spectrum) do
        local bar_h = math.clamp(math.floor(val * 11) + 3, 3, 14)
        table.insert(spectrum_bars, Zenith.Box({
            width = 2,
            height = bar_h,
            border_radius = 1,
            background = Zenith.hex(theme.primary),
        }))
    end

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { x = if screen_w < 1440 then 8 else 10, y = 2 },
        gap = 5,
        background = Zenith.hex(theme.surface_container_high or theme.surface_container, 140),
        border_color = Zenith.hex(theme.primary, 90),
        on_click = "popup:toggle:MediaPopup",
        children = {
            Zenith.Text({
                text = status_icon,
                font_size = 12,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = label,
                font_size = 11,
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({
                direction = "row",
                align_items = "flex-end",
                gap = 2,
                height = 14,
                children = spectrum_bars,
            })
        }
    })
end

return MediaWidget
