--!strict
-- Zenith-Shell: Pomodoro Timer Details Popup

local Store = Zenith.import("core/store")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function PomodoroPopup()
    local theme = Theme.get()
    local active = Store.get("pomodoroActive") or false
    local focus_min = Store.get("pomodoroFocus") or 25
    local break_min = Store.get("pomodoroBreak") or 5

    return Zenith.Box({
        direction = "column",
        width = 300,
        height = 240,
        padding = { horizontal = 16, vertical = 14 },
        gap = 12,
        background = Zenith.hex(theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
        border_width = 1,
        border_radius = 16,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 180),
            blur = 20,
            offset_x = 0,
            offset_y = 8,
        },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = "󰅐 Pomodoro Timer",
                        font_size = 13,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container),
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                        }
                    }),
                }
            }),

            Zenith.Box({
                direction = "column",
                align_items = "center",
                justify_content = "center",
                gap = 4,
                padding = { horizontal = 10, vertical = 12 },
                border_radius = 12,
                background = Zenith.hex(theme.surface_container_high or theme.surface_container, 120),
                children = {
                    Zenith.Text({
                        text = string.format("%02d:00", focus_min),
                        font_size = 32,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = if active then "Sessão de foco ativa" else "Pronto para iniciar",
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface_variant or theme.outline),
                    }),
                }
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "space_between",
                gap = 8,
                children = {
                    Zenith.Box({
                        flex_grow = 1,
                        padding = { horizontal = 10, vertical = 8 },
                        border_radius = 8,
                        background = if active then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary),
                        align_items = "center",
                        justify_content = "center",
                        cursor = "pointer",
                        on_click = "storage:toggle:pomodoroActive",
                        children = {
                            Zenith.Text({
                                text = if active then "Pausar" else "Iniciar",
                                font_size = 11,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_primary),
                            })
                        }
                    }),
                    Zenith.Box({
                        padding = { horizontal = 12, vertical = 8 },
                        border_radius = 8,
                        background = Zenith.hex(theme.surface_container),
                        align_items = "center",
                        justify_content = "center",
                        cursor = "pointer",
                        on_click = "storage:set:pomodoroFocus:25",
                        children = {
                            Zenith.Text({
                                text = "Reset",
                                font_size = 11,
                                color = Zenith.hex(theme.on_surface),
                            })
                        }
                    })
                }
            })
        }
    })
end

return PomodoroPopup
