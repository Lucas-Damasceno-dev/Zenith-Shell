--!strict
-- Zenith Desktop Shell — Session Lock Screen Overlay
-- Fullscreen lock surface with PAM/anti-brute-force integration and reactive signals

local Theme = Zenith.import("core/theme")
local Button = Zenith.import("core/ui/button")
local Card = Zenith.import("core/ui/card")

local function LockScreen()
    local theme = Theme.get()

    local username = if Zenith.user then Zenith.user() else "Zenith User"
    local time_val = if Zenith.Signals and Zenith.Signals.Time
        then (if type(Zenith.Signals.Time) == "function" then Zenith.Signals.Time() else Zenith.Signals.Time)
        else os.date("%H:%M")
    local date_val = if Zenith.Signals and Zenith.Signals.Date
        then (if type(Zenith.Signals.Date) == "function" then Zenith.Signals.Date() else Zenith.Signals.Date)
        else os.date("%A, %d de %B")

    local is_locked = if Zenith.is_locked_out then Zenith.is_locked_out() else false
    local rem_secs = if Zenith.lockout_remaining_secs then Zenith.lockout_remaining_secs() else 0
    local pass_disp = if Zenith.lock_pass_display then Zenith.lock_pass_display() else "Digite a senha para desbloquear...▎"

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        height = "100%",
        padding = 48,
        background = Zenith.rgba(12, 14, 20, 245),
        children = {
            -- Top Time & Date Header
            Zenith.Box({
                direction = "column",
                align_items = "center",
                gap = 6,
                children = {
                    Zenith.Text({
                        text = time_val,
                        font_family = "Inter",
                        font_size = 64,
                        font_weight = "bold",
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Text({
                        text = date_val,
                        font_family = "Inter",
                        font_size = 16,
                        font_weight = "medium",
                        color = Zenith.hex(theme.primary),
                    }),
                },
            }),

            -- Center Authentication Card
            Card({
                variant = "glass",
                padding = 28,
                gap = 18,
                children = {
                    Zenith.Box({
                        direction = "column",
                        align_items = "center",
                        gap = 12,
                        children = {
                            Zenith.Box({
                                width = 80,
                                height = 80,
                                border_radius = 40,
                                background = Zenith.hex(theme.primary_container, 180),
                                border_color = Zenith.hex(theme.primary, 140),
                                border_width = 2,
                                align_items = "center",
                                justify_content = "center",
                                children = {
                                    Zenith.Text({
                                        text = "󰌽",
                                        font_family = "JetBrainsMono Nerd Font",
                                        font_size = 36,
                                        color = Zenith.hex(theme.primary),
                                    }),
                                },
                            }),
                            Zenith.Text({
                                text = username,
                                font_family = "Inter",
                                font_size = 18,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_surface),
                            }),
                        },
                    }),

                    -- Lockout message or Password field
                    if is_locked then
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            justify_content = "center",
                            width = 300,
                            height = 44,
                            padding = { horizontal = 16, vertical = 8 },
                            border_radius = 14,
                            background = Zenith.hex(theme.error or "#f38ba8", 40),
                            border_color = Zenith.hex(theme.error or "#f38ba8", 120),
                            border_width = 1,
                            children = {
                                Zenith.Text({
                                    text = string.format("Bloqueado temporariamente (%ds)", rem_secs),
                                    font_family = "Inter",
                                    font_size = 13,
                                    font_weight = "semibold",
                                    color = Zenith.hex(theme.error or "#f38ba8"),
                                }),
                            },
                        })
                    else
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            justify_content = "center",
                            width = 300,
                            height = 44,
                            padding = { horizontal = 16, vertical = 8 },
                            border_radius = 14,
                            background = Zenith.hex(theme.surface_container_highest, 120),
                            border_color = Zenith.hex(theme.outline_variant or theme.outline, 60),
                            border_width = 1,
                            children = {
                                Zenith.Text({
                                    text = pass_disp,
                                    font_family = "JetBrainsMono Nerd Font",
                                    font_size = 13,
                                    color = Zenith.hex(theme.on_surface),
                                }),
                            },
                        }),

                    Button({
                        label = "Desbloquear",
                        icon = "󰌾",
                        variant = "primary",
                        width = 300,
                        on_click = "lock:unlock",
                    }),
                },
            }),

            -- Bottom Power Actions
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 16,
                children = {
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Suspender",
                        on_click = "system:suspend",
                        padding = 8,
                        children = {
                            Zenith.Text({ text = "󰤄", font_size = 20, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Reiniciar",
                        on_click = "system:reboot",
                        padding = 8,
                        children = {
                            Zenith.Text({ text = "󰜉", font_size = 20, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Desligar",
                        on_click = "system:poweroff",
                        padding = 8,
                        children = {
                            Zenith.Text({ text = "󰐥", font_size = 20, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                },
            }),
        },
    })
end

return LockScreen()
