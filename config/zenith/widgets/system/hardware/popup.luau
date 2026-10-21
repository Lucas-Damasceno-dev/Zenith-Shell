--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local Card = Zenith.import("core/ui/card")
local Slider = Zenith.import("core/ui/slider")
local Button = Zenith.import("core/ui/button")
local Services = Zenith.import("core/services/init")

return function()
    local cpu = Services.Hardware.cpu()
    local mem = Services.Hardware.memory()
    local dsk = Services.Hardware.disk()
    local bri = Services.Hardware.brightness()
    local t = Theme.get()

    return Card({
        variant = "glass",
        width = 320,
        gap = 14,
        padding = 16,
        children = {
            Zenith.Text({
                text = "Monitor do Sistema",
                font_family = "JetBrainsMono Nerd Font",
                font_size = 15,
                font_weight = "bold",
                color = t.on_surface or "#ffffff",
            }),
            Zenith.Box({
                width = "100%",
                flex_direction = "column",
                gap = 6,
                children = {
                    Zenith.Text({ text = string.format("CPU: %s (%d%% uso)", cpu.model or "Processador", math.floor(cpu.usage_percent or cpu.percent or 0)), font_family = "JetBrainsMono Nerd Font", font_size = 12, color = t.on_surface or "#ffffff" }),
                    Zenith.Text({ text = string.format("RAM: %d MB / %d MB (%d%%)", mem.used_mb or 0, mem.total_mb or 0, math.floor(mem.percent or 0)), font_family = "JetBrainsMono Nerd Font", font_size = 12, color = t.on_surface or "#ffffff" }),
                    Zenith.Text({ text = string.format("Disco: %d GB / %d GB (%d%%)", dsk.used_gb or 0, dsk.total_gb or 0, math.floor(dsk.percent or 0)), font_family = "JetBrainsMono Nerd Font", font_size = 12, color = t.on_surface or "#ffffff" }),
                },
            }),
            Slider({
                label = "Brilho da Tela",
                min = 1,
                max = 100,
                value = bri,
                show_value = true,
                icon_left = Icons.glyphs.brightness_low,
                icon_right = Icons.glyphs.brightness,
                on_change = "brightness:set:",
            }),
            Button({
                label = "Abrir Monitor Completo (htop)",
                icon = Icons.glyphs.terminal,
                variant = "tonal",
                width = "100%",
                on_click = "cmd:foot -e htop",
            }),
        },
    })
end
