--!strict
local Theme = Zenith.import("core/theme")
local Icons = Zenith.import("core/ui/icons")
local PopupManager = Zenith.import("core/popup_manager")
local Services = Zenith.import("core/services/init")

return function(props: any?)
    local cpu = Services.Hardware.cpu()
    local mem = Services.Hardware.memory()
    local t = Theme.get()

    local cpu_val = cpu.usage_percent or cpu.percent or 0
    local mem_val = mem.percent or 0

    return Zenith.Box({
        flex_direction = "row",
        align_items = "center",
        gap = 8,
        padding = { horizontal = 8, vertical = 4 },
        background = Theme.alpha(t.surface_container or t.surface, 150),
        border_radius = 12,
        on_click = PopupManager.toggle_action("SystemMonitorPopup"),
        on_right_click = "cmd:foot -e htop",
        tooltip = string.format("Hardware: CPU %d%% | RAM %d%%", math.floor(cpu_val), math.floor(mem_val)),
        children = {
            Zenith.Box({
                flex_direction = "row",
                align_items = "center",
                gap = 4,
                children = {
                    Zenith.Text({ text = Icons.glyphs.cpu, font_family = "JetBrainsMono Nerd Font", font_size = 13, color = t.primary or "#7c4dff" }),
                    Zenith.Text({ text = string.format("%d%%", math.floor(cpu_val)), font_family = "JetBrainsMono Nerd Font", font_size = 11, color = t.on_surface or "#ffffff" }),
                },
            }),
            Zenith.Box({
                flex_direction = "row",
                align_items = "center",
                gap = 4,
                children = {
                    Zenith.Text({ text = Icons.glyphs.memory, font_family = "JetBrainsMono Nerd Font", font_size = 13, color = t.secondary or "#625b71" }),
                    Zenith.Text({ text = string.format("%d%%", math.floor(mem_val)), font_family = "JetBrainsMono Nerd Font", font_size = 11, color = t.on_surface or "#ffffff" }),
                },
            }),
        },
    })
end
