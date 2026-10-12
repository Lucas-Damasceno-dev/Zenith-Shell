--!strict
-- Zenith Design System - Theme & Design Tokens
-- Seamless bidirectional integration with Matugen (Material You M3) and Stylix (Base16)

local Theme = {}

function Theme.get()
    return Zenith.Theme()
end

function Theme.alpha(hex_or_color: any, alpha: number)
    if typeof(hex_or_color) == "string" then
        return Zenith.hex(hex_or_color, alpha)
    end
    return hex_or_color
end

-- Preset glassmorphic surface parameters for modern Wayland desktop
function Theme.glass(variant: string?, custom_radius: number?)
    local t = Theme.get()
    local v = variant or "default"
    local r = custom_radius or 16

    if v == "elevated" then
        return {
            background = Theme.alpha(t.surface_container_high or t.surface, 210),
            border_color = Theme.alpha(t.outline_variant or t.outline, 70),
            border_width = 1,
            border_radius = r,
            shadow = {
                color = Theme.alpha(t.background or "#000000", 90),
                blur = 18,
                offset_x = 0,
                offset_y = 6,
            },
        }
    elseif v == "outlined" then
        return {
            background = Theme.alpha(t.surface_container_low or t.surface, 150),
            border_color = Theme.alpha(t.outline or "#ffffff", 110),
            border_width = 1.5,
            border_radius = r,
            shadow = nil,
        }
    elseif v == "frosted" or v == "glass" then
        return {
            background = Theme.alpha(t.surface or t.base00 or "#1e1e2e", 175),
            border_color = Theme.alpha(t.outline_variant or "#ffffff", 55),
            border_width = 1,
            border_radius = r,
            shadow = {
                color = Theme.alpha("#000000", 75),
                blur = 20,
                offset_x = 0,
                offset_y = 8,
            },
        }
    else -- default surface
        return {
            background = Theme.alpha(t.surface_container or t.surface, 190),
            border_color = Theme.alpha(t.outline_variant or t.outline, 45),
            border_width = 1,
            border_radius = r,
            shadow = {
                color = Theme.alpha(t.background or "#000000", 60),
                blur = 12,
                offset_x = 0,
                offset_y = 4,
            },
        }
    end
end

return Theme
