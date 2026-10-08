--!strict
-- Zenith UI Kit - Media Pill Component (MPRIS2 / Caelestia style)

local function MediaWidget()
    local theme = Zenith.Theme()
    local media = Zenith.Services.Media()

    if not media.is_available or media.status == "Stopped" then
        return Zenith.Box({
            direction = "row",
            padding = { x = 10, y = 3 },
            gap = 6,
            border_radius = 12,
            background = Zenith.rgba(255, 255, 255, 8),
            border_color = Zenith.rgba(255, 255, 255, 16),
            border_width = 1,
            on_click = "popup:toggle:MediaPopup",
            children = {
                Zenith.Text({
                    text = "󰎆 Idle",
                    font_size = 11,
                    color = Zenith.rgba(255, 255, 255, 120),
                })
            }
        })
    end

    local status_icon = if media.status == "Playing" then "󰐊" else "󰏤"
    local label = if #media.artist > 0 then
        string.format("%s - %s", media.artist, media.title)
    else
        media.title

    if #label > 28 then
        label = label:sub(1, 25) .. "..."
    end

    local spectrum = Zenith.Services.Spectrum(4)
    local spectrum_bars = {}
    for _, val in ipairs(spectrum) do
        local bar_h = math.clamp(math.floor(val * 10) + 2, 2, 12)
        table.insert(spectrum_bars, Zenith.Box({
            width = 2,
            height = bar_h,
            border_radius = 1,
            background = Zenith.hex(theme.primary),
        }))
    end

    return Zenith.Box({
        direction = "row",
        padding = { x = 11, y = 3 },
        gap = 6,
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 14),
        border_color = Zenith.rgba(122, 162, 247, 90),
        border_width = 1,
        on_click = "popup:toggle:MediaPopup",
        children = {
            Zenith.Text({
                text = status_icon,
                font_size = 11,
                color = Zenith.hex(theme.primary),
            }),
            Zenith.Text({
                text = label,
                font_size = 11,
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Box({
                direction = "row",
                gap = 2,
                height = 12,
                children = spectrum_bars,
            })
        }
    })
end

return MediaWidget
