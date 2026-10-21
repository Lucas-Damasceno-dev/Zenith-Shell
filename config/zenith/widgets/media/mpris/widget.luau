--!strict
-- Zenith-Shell: MPRIS Media Pill Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")

local function MediaWidget()
    local theme = Theme.get()
    local media = Services.Mpris.snapshot()

    if not media.is_available or media.status == "Stopped" then
        return Pill({
            height = 26,
            border_radius = 13,
            padding = { horizontal = 8, vertical = 2 },
            icon = "󰎆",
            icon_size = 12,
            icon_color = Zenith.hex(theme.on_surface_variant or theme.outline, 140),
            on_click = PopupManager.toggle_action("MediaPopup"),
        })
    end

    local status_icon = if media.status == "Playing" then "󰐊" else "󰏤"
    local artist = media.artist or ""
    local title = media.title or ""
    local label = if #artist > 0 then string.format("%s - %s", artist, title) else title

    local screen = if Zenith.Services and Zenith.Services.Screen then Zenith.Services.Screen() else { width = 1366 }
    local screen_w = screen.width or 1366
    local max_len = if screen_w < 1200 then 10 elseif screen_w < 1440 then 13 elseif screen_w < 1920 then 20 else 32

    if #label > max_len then
        label = label:sub(1, max_len - 2) .. ".."
    end

    local spectrum = Services.Audio.spectrum(4)
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
        padding = { horizontal = if screen_w < 1440 then 8 else 10, vertical = 2 },
        background = Zenith.hex(theme.surface_container_high or theme.surface_container, 140),
        border_color = Zenith.hex(theme.primary, 90),
        tooltip = "Reprodutor de Mídia • " .. label .. "\n• Clique: Painel MPRIS\n• Botão Direito: Próxima Faixa\n• Scroll: Alternar Faixas",
        on_click = PopupManager.toggle_action("MediaPopup"),
        on_right_click = "media:next",
        on_scroll_up = "media:next",
        on_scroll_down = "media:previous",
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
                align_items = "flex_end",
                gap = 2,
                height = 14,
                children = spectrum_bars,
            })
        }
    })
end

return MediaWidget
