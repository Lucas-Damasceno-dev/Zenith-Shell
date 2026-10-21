--!strict
-- Zenith Desktop Shell — Screen Draw & Annotation HUD Overlay
-- Toolbar controlling desktop annotation engines (gromit-mpx / wl-screenrec)

local Theme = Zenith.import("core/theme")
local Card = Zenith.import("core/ui/card")
local Button = Zenith.import("core/ui/button")

local function ScreenDrawOverlay()
    local theme = Theme.get()

    return Card({
        variant = "glass",
        width = 440,
        padding = 14,
        gap = 12,
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
                        gap = 8,
                        children = {
                            Zenith.Text({ text = "󰽉", font_size = 18, color = Zenith.hex(theme.primary) }),
                            Zenith.Text({
                                text = "Anotações na Tela",
                                font_family = "Inter",
                                font_size = 14,
                                font_weight = "bold",
                                color = Zenith.hex(theme.on_surface),
                            }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        tooltip = "Fechar",
                        on_click = "popup:close",
                        padding = 4,
                        children = {
                            Zenith.Text({ text = "󰅖", font_size = 14, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                },
            }),
            Zenith.Box({
                direction = "row",
                gap = 8,
                width = "100%",
                children = {
                    Button({
                        label = "Pincel",
                        icon = "󰽉",
                        variant = "primary",
                        on_click = "cmd:gromit-mpx --toggle",
                    }),
                    Button({
                        label = "Limpar",
                        icon = "󰃢",
                        variant = "tonal",
                        on_click = "cmd:gromit-mpx --clear",
                    }),
                    Button({
                        label = "Desfazer",
                        icon = "󰕌",
                        variant = "outlined",
                        on_click = "cmd:gromit-mpx --undo",
                    }),
                    Button({
                        label = "Visibilidade",
                        icon = "󰈈",
                        variant = "outlined",
                        on_click = "cmd:gromit-mpx --visibility",
                    }),
                },
            }),
        },
    })
end

return ScreenDrawOverlay()
