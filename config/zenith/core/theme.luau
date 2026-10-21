--!strict
-- Zenith Desktop Shell — Core Design System Tokens & Theming
-- Seamless bidirectional integration with Matugen (Material You M3) and Stylix (Base16)

local Theme = {}

local _cached_icons = nil
function Theme.icons()
    if not _cached_icons then
        local ok, mod = pcall(function() return Zenith.import("core/ui/icons") end)
        if ok and mod then
            _cached_icons = mod
        else
            _cached_icons = {}
        end
    end
    return _cached_icons
end

function Theme.get()
    if Zenith.Theme then
        return Zenith.Theme()
    end
    return {
        primary = "#7c4dff",
        on_primary = "#ffffff",
        primary_container = "#4f378b",
        on_primary_container = "#eaddff",
        secondary = "#625b71",
        on_secondary = "#ffffff",
        tertiary = "#7d5260",
        on_tertiary = "#ffffff",
        error = "#f38ba8",
        surface = "#141218",
        surface_variant = "#44474f",
        on_surface_variant = "#c4c7c5",
        surface_container = "#211f26",
        surface_container_low = "#1a181e",
        surface_container_high = "#2b2930",
        surface_container_highest = "#36343b",
        on_surface = "#e6e0e9",
        outline = "#938f99",
        outline_variant = "#49454f",
        background = "#141218",
    }
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
    local r = custom_radius or 14

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
    elseif v == "island" then
        return {
            background = Theme.alpha(t.surface or "#18202b", 235),
            border_color = Theme.alpha(t.outline_variant or t.outline or "#ffffff", 65),
            border_width = 1,
            border_radius = custom_radius or 20,
            shadow = {
                color = Theme.alpha("#000000", 140),
                blur = 20,
                offset_x = 0,
                offset_y = 6,
            },
        }
    elseif v == "dock" then
        return {
            background = Theme.alpha(t.surface_container or t.surface or "#18202b", 215),
            border_color = Theme.alpha(t.outline_variant or t.outline or "#ffffff", 55),
            border_width = 1,
            border_radius = custom_radius or 24,
            shadow = {
                color = Theme.alpha("#000000", 150),
                blur = 24,
                offset_x = 0,
                offset_y = 8,
            },
        }
    elseif v == "canvas_card" then
        return {
            background = Theme.alpha(t.surface_container_low or t.surface or "#18202b", 165),
            border_color = Theme.alpha(t.outline_variant or t.outline or "#ffffff", 45),
            border_width = 1,
            border_radius = custom_radius or 24,
            shadow = {
                color = Theme.alpha("#000000", 110),
                blur = 28,
                offset_x = 0,
                offset_y = 8,
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
            primary = t.primary or "#7c4dff",
            on_primary = t.on_primary or "#ffffff",
            primary_container = t.primary_container or t.surface_container_high or "#7c4dff",
            secondary = t.secondary or "#625b71",
            on_secondary = t.on_secondary or "#ffffff",
            tertiary = t.tertiary or "#7d5260",
            on_tertiary = t.on_tertiary or "#ffffff",
            error = t.error or "#f38ba8",
            background = t.background or "#0c141bf2",
            surface = t.surface or "#18202bcc",
            on_surface = t.on_surface or "#dbe3ed",
            surface_variant = t.surface_variant or "#44474f",
            on_surface_variant = t.on_surface_variant or "#c4c7c5",
            surface_container = t.surface_container or t.surface,
            surface_container_low = t.surface_container_low or t.surface,
            surface_container_high = t.surface_container_high or t.surface,
            surface_container_highest = t.surface_container_highest or t.surface,
            outline = t.outline or "#74777f",
            outline_variant = t.outline_variant or "#44474f",
            red = t.red or t.error or "#f38ba8",
            peach = t.peach or "#fab387",
            yellow = t.yellow or "#f9e2af",
            green = t.green or "#a6e3a1",
            teal = t.teal or "#94e2d5",
            blue = t.blue or "#89b4fa",
            mauve = t.mauve or "#cba6f7",
            lavender = t.lavender or "#b4befe",
            base00 = t.base00 or "#18202b",
            base01 = t.base01 or "#222c3a",
            base02 = t.base02 or "#2d3b4e",
            base03 = t.base03 or "#44556d",
            base04 = t.base04 or "#6f829d",
            base05 = t.base05 or "#dbe3ed",
            base06 = t.base06 or "#e4ecf7",
            base07 = t.base07 or "#f1f6fd",
        }
    }
end

return Theme
