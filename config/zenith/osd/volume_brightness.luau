--!strict
-- Zenith Desktop Shell — OSD Volume & Brightness Indicator
-- Displays real-time audio and backlight progress bars

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local Store = Zenith.import("core/store")
local OsdDefaults = Zenith.import("osd/defaults")

local function VolumeBrightnessOsd()
    local theme = Theme.get()
    local mode = Store.get("osd_mode", "volume")

    local icon = "󰕾"
    local label = "Volume"
    local value = 50
    local is_muted = false

    if mode == "brightness" then
        label = "Brilho"
        value = Services.Hardware.brightness()
        icon = if value > 60 then "󰃠" elseif value > 20 then "󰃟" else "󰃞"
    else
        local audio = Services.Audio.status()
        value = audio.volume or 50
        is_muted = audio.muted or false
        icon = if is_muted then "󰝟" elseif value > 60 then "󰕾" elseif value > 20 then "󰖀" else "󰕿"
    end

    local track_width = OsdDefaults.width - 36
    local fill_width = math.max(0, math.min(track_width, math.round((value / 100.0) * track_width)))

    return Zenith.Box({
        direction = "column",
        justify_content = "center",
        width = OsdDefaults.width,
        height = OsdDefaults.height,
        padding = { horizontal = 18, vertical = 12 },
        border_radius = OsdDefaults.border_radius,
        background = Zenith.hex(theme.surface_container_highest or theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 70),
        border_width = 1,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 160),
            blur = 20,
            offset_x = 0,
            offset_y = 6,
        },
        gap = 10,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                width = "100%",
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 10,
                        children = {
                            Zenith.Text({
                                text = icon,
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 18,
                                color = if is_muted
                                    then Zenith.hex(theme.error or "#f38ba8")
                                    else Zenith.hex(theme.primary),
                            }),
                            Zenith.Text({
                                text = label,
                                font_family = "Inter",
                                font_size = 13,
                                font_weight = "medium",
                                color = Zenith.hex(theme.on_surface),
                            }),
                        },
                    }),
                    Zenith.Text({
                        text = if is_muted then "Mudo" else string.format("%d%%", value),
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 12,
                        font_weight = "bold",
                        color = if is_muted
                            then Zenith.hex(theme.error or "#f38ba8")
                            else Zenith.hex(theme.primary),
                    }),
                },
            }),
            -- Progress Bar Track
            Zenith.Box({
                direction = "row",
                width = track_width,
                height = OsdDefaults.slider_height,
                border_radius = math.round(OsdDefaults.slider_height * 0.5),
                background = Zenith.hex(theme.surface_container, 180),
                children = {
                    Zenith.Box({
                        width = fill_width,
                        height = OsdDefaults.slider_height,
                        border_radius = math.round(OsdDefaults.slider_height * 0.5),
                        background = if is_muted
                            then Zenith.hex(theme.error or "#f38ba8")
                            else Zenith.hex(theme.primary),
                    }),
                },
            }),
        },
    })
end

return VolumeBrightnessOsd
