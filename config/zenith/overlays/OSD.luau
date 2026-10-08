--!strict
-- Zenith-Shell (Engine v2) - On-Screen Display (OSD) Overlay
-- Provides instant visual feedback for Volume, Brightness, and Media adjustments.

local theme = Zenith.Theme()
local audio = Zenith.Services.audio()

local vol = audio.volume
local is_muted = audio.is_muted
local vol_icon = is_muted and "󰝟" or (vol > 60 and "" or (vol > 20 and "" or ""))
local title_label = is_muted and "Muted" or string.format("%d%%", vol)

-- Progress bar width calculation (220px total track width)
local bar_total_width = 220
local bar_filled_width = math.floor((vol / 100) * bar_total_width)
if bar_filled_width < 4 and vol > 0 then
    bar_filled_width = 4
end

return Zenith.Window({
    direction = "column",
    width = 260,
    height = 110,
    padding = { x = 20, y = 16 },
    gap = 12,
    background = Zenith.rgba(18, 20, 26, 230),
    border_color = Zenith.hex(theme.primary),
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 24,
        offset_x = 0,
        offset_y = 10,
    },
    children = {
        -- Header with large icon and percentage label
        Zenith.Box({
            direction = "row",
            children = {
                Zenith.Text({
                    text = vol_icon .. " Volume",
                    font_size = 14,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = title_label,
                    font_size = 14,
                    color = is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.on_surface),
                }),
            }
        }),

        -- Horizontal Progress Track
        Zenith.Box({
            width = bar_total_width,
            height = 8,
            border_radius = 4,
            background = Zenith.hex(theme.surface_container),
            direction = "row",
            children = {
                Zenith.Box({
                    width = bar_filled_width,
                    height = 8,
                    border_radius = 4,
                    background = is_muted and Zenith.hex("#e06c75") or Zenith.hex(theme.primary),
                }),
            }
        }),
    }
})
