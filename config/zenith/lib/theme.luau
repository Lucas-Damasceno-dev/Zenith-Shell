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
    elseif v == "accent" then
        return {
            background = Theme.alpha(t.primary or "#7c4dff", 40),
            border_color = Theme.alpha(t.primary or "#7c4dff", 110),
            border_width = 1,
            border_radius = r,
            shadow = {
                color = Theme.alpha(t.primary or "#000000", 45),
                blur = 14,
                offset_x = 0,
                offset_y = 4,
            },
        }
    elseif v == "subtle" then
        return {
            background = Theme.alpha(t.surface_container_lowest or t.surface_container or t.surface, 110),
            border_color = Theme.alpha(t.outline_variant or t.outline, 30),
            border_width = 1,
            border_radius = r,
            shadow = nil,
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

-- Material Design 3 elevation shadows
function Theme.elevation(level: number?)
    local lvl = level or 1
    local t = Theme.get()
    local shadow_col = Theme.alpha(t.background or "#000000", math.min(30 + lvl * 25, 200))

    if lvl == 0 then
        return nil
    elseif lvl == 1 then
        return { color = shadow_col, blur = 8, offset_x = 0, offset_y = 2 }
    elseif lvl == 2 then
        return { color = shadow_col, blur = 14, offset_x = 0, offset_y = 4 }
    elseif lvl == 3 then
        return { color = shadow_col, blur = 18, offset_x = 0, offset_y = 6 }
    elseif lvl == 4 then
        return { color = shadow_col, blur = 24, offset_x = 0, offset_y = 8 }
    else -- level 5
        return { color = shadow_col, blur = 32, offset_x = 0, offset_y = 12 }
    end
end

-- Resolve token color with safe fallback
function Theme.color(token_name: string, fallback: any?)
    local t = Theme.get()
    local val = (t :: any)[token_name]
    if val ~= nil then
        return val
    end
    return fallback or "#ffffff"
end

-- Synchronized Design Tokens with Matugen (M3) and Stylix (Base16)
function Theme.tokens()
    local t = Theme.get()
    return {
        colors = {
            -- Material 3 Core
            primary = t.primary or "#7c4dff",
            on_primary = t.on_primary or "#ffffff",
            primary_container = t.primary_container or t.surface_container_high or "#7c4dff",
            secondary = t.secondary or "#625b71",
            on_secondary = t.on_secondary or "#ffffff",
            tertiary = t.tertiary or "#7d5260",
            on_tertiary = t.on_tertiary or "#ffffff",
            error = t.error or "#f38ba8",
            -- Surfaces
            background = t.background or "#0c141bf2",
            surface = t.surface or "#18202bcc",
            on_surface = t.on_surface or "#dbe3ed",
            surface_variant = t.surface_variant or "#44474f",
            on_surface_variant = t.on_surface_variant or "#c4c7c5",
            surface_container = t.surface_container or t.surface,
            surface_container_low = t.surface_container_low or t.surface,
            surface_container_high = t.surface_container_high or t.surface,
            surface_container_highest = t.surface_container_highest or t.surface,
            -- Outlines
            outline = t.outline or "#74777f",
            outline_variant = t.outline_variant or "#44474f",
            -- Semantic aliases
            red = t.red or t.error or "#f38ba8",
            peach = t.peach or "#fab387",
            yellow = t.yellow or "#f9e2af",
            green = t.green or "#a6e3a1",
            teal = t.teal or "#94e2d5",
            blue = t.blue or "#89b4fa",
            mauve = t.mauve or "#cba6f7",
            lavender = t.lavender or "#b4befe",
            -- Base16 (Stylix)
            base00 = t.base00 or "#18202b",
            base01 = t.base01 or "#222c3a",
            base02 = t.base02 or "#2d3b4e",
            base03 = t.base03 or "#44556d",
            base04 = t.base04 or "#6f829d",
            base05 = t.base05 or "#dbe3ed",
            base06 = t.base06 or "#eaf0f8",
            base07 = t.base07 or "#ffffff",
            base08 = t.base08 or "#f38ba8",
            base09 = t.base09 or "#fab387",
            base0a = t.base0a or "#f9e2af",
            base0b = t.base0b or "#a6e3a1",
            base0c = t.base0c or "#94e2d5",
            base0d = t.base0d or "#89b4fa",
            base0e = t.base0e or "#cba6f7",
            base0f = t.base0f or "#b4befe",
        },
        typography = {
            caption = 10,
            body_small = 11,
            body = 12,
            body_large = 13,
            title = 14,
            headline = 18,
        },
        shapes = {
            none = 0,
            xs = 4,
            sm = 8,
            md = 12,
            lg = 16,
            full = 9999,
        },
        spacing = {
            xs = 2,
            sm = 4,
            md = 8,
            lg = 12,
            xl = 16,
        },
    }
end

return Theme
