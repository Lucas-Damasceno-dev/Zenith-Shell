--!strict
-- Zenith-Shell (Engine v2) - On-Screen Display (OSD) Overlay
-- Minimalist feedback popup for Volume & Brightness, auto-dismissed after 2 seconds.

local theme = Zenith.Theme()

-- Check if OSD mode is brightness or volume
local osd_mode = "volume"
if Zenith.Storage and Zenith.Storage.has and Zenith.Storage.has("osd_mode") then
    osd_mode = Zenith.Storage.get("osd_mode", "volume")
end

local bar_total_width = 220
local title_label = ""
local mode_icon = ""
local mode_name = ""
local filled_pct = 0
local is_alert = false

if osd_mode == "brightness" then
    local bright = (Zenith.Services.Brightness and Zenith.Services.Brightness()) or (Zenith.Services.brightness and Zenith.Services.brightness()) or { percent = 100 }
    filled_pct = math.clamp(bright.percent or 100, 0, 100)
    mode_icon = if filled_pct > 70 then "󰃠" elseif filled_pct > 30 then "󰃟" else "󰃞"
    mode_name = "Brilho"
    title_label = string.format("%d%%", filled_pct)
else
    local audio = Zenith.Services.audio()
    local vol = audio.volume or 0
    local is_muted = audio.is_muted or false
    filled_pct = math.clamp(vol, 0, 100)
    mode_icon = if is_muted then "󰝟" elseif vol > 60 then "" elseif vol > 20 then "" else ""
    mode_name = "Volume"
    title_label = if is_muted then "Mudo" else string.format("%d%%", vol)
    is_alert = is_muted
end

local bar_filled_width = math.floor((filled_pct / 100) * bar_total_width)
if bar_filled_width < 4 and filled_pct > 0 then
    bar_filled_width = 4
end

-- Auto-dismiss popup after 2000ms via native Zero-Subprocess socket
if Zenith.delay then
    Zenith.delay(2000):andThen(function()
        if Zenith.close then
            Zenith.close()
        end
    end)
end

return Zenith.Window({
    direction = "column",
    width = 260,
    height = 96,
    padding = { x = 18, y = 14 },
    gap = 10,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
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
            align_items = "center",
            children = {
                Zenith.Text({
                    text = mode_icon .. " " .. mode_name,
                    font_size = 13,
                    font_weight = "medium",
                    color = if is_alert then Zenith.hex(theme.error or "#ff865c") else Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = title_label,
                    font_size = 13,
                    font_weight = "medium",
                    color = if is_alert then Zenith.hex(theme.error or "#ff865c") else Zenith.hex(theme.on_surface),
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
                    background = if is_alert then Zenith.hex(theme.error or "#ff865c") else Zenith.hex(theme.primary),
                }),
            }
        }),
    }
})
