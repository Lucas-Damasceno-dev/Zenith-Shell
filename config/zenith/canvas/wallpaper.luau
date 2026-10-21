--!strict
-- Zenith Desktop Shell — Desktop Wallpaper Surface
-- Supports swww image rendering and dynamic fallback backdrop

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")

local function WallpaperSurface()
    local theme = Theme.get()
    local wallpaper_path = Store.get("wallpaperPath", "")

    local screen_w = 1920
    local screen_h = 1080
    if Zenith.Services and Zenith.Services.Screen then
        local scr = Zenith.Services.Screen()
        if scr and scr.width and scr.height and scr.width > 0 and scr.height > 0 then
            screen_w = scr.width
            screen_h = scr.height
        end
    end

    if wallpaper_path ~= "" then
        return Zenith.Image({
            src = wallpaper_path,
            width = screen_w,
            height = screen_h,
        })
    end

    return Zenith.Box({
        width = screen_w,
        height = screen_h,
        background = Zenith.hex(theme.background or "#0e1015"),
    })
end

return WallpaperSurface
