--!strict
-- Zenith Desktop Shell — Screenshot & Screen Capture Overlay
-- Quick action HUD for region snips, full display capture and screen recording

local Theme = Zenith.import("core/theme")
local Button = Zenith.import("core/ui/button")
local Card = Zenith.import("core/ui/card")

local function ScreenshotOverlay()
    local theme = Theme.get()

    return Card({
        variant = "glass",
        width = 380,
        padding = 18,
        gap = 14,
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
                            Zenith.Text({ text = "󰹑", font_size = 18, color = Zenith.hex(theme.primary) }),
                            Zenith.Text({
                                text = "Captura de Tela & Gravação",
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
                gap = 10,
                width = "100%",
                children = {
                    Button({
                        label = "Região",
                        icon = "󰄀",
                        variant = "primary",
                        on_click = "screenshot:area",
                    }),
                    Button({
                        label = "Tela Inteira",
                        icon = "󰹑",
                        variant = "tonal",
                        on_click = "screenshot:full",
                    }),
                    Button({
                        label = "Gravar",
                        icon = "󰕧",
                        variant = "outlined",
                        on_click = "record:toggle",
                    }),
                },
            }),
        },
    })
end

return ScreenshotOverlay()
