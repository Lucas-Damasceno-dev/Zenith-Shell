--!strict
-- Zenith UI Kit - Hardware Monitor Component (Quickshell / Caelestia style)

local Pill = Zenith.import("widgets/pill")

local function Hardware(props: { reactive: boolean? }?)
    local theme = Zenith.Theme()
    local mem = Zenith.Services.memory()
    local cpu = Zenith.Services.cpu()
    local disk = (Zenith.Services.disk and Zenith.Services.disk()) or { total_gb = 0, used_gb = 0, percent = 0 }

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local pad_x = if screen_w < 1440 then 7 else 9

    local cpu_color = if cpu.percent > 85 then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)
    local mem_color = if mem.percent > 85 then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)
    local disk_color = if disk.percent > 90 then Zenith.hex(theme.error or "#f38ba8") else Zenith.hex(theme.primary)

    -- Granular reactive bindings for zero-redundancy hardware metrics
    local is_reactive = if props and props.reactive ~= nil then props.reactive else true
    local cpu_binding = if is_reactive and Zenith.Signals and Zenith.Signals.Cpu then Zenith.Signals.Cpu else string.format("%d%%", cpu.percent)
    local mem_binding = if is_reactive and Zenith.Signals and Zenith.Signals.Memory then Zenith.Signals.Memory else string.format("%d%%", mem.percent)

    local tip = string.format("CPU: %d%% | RAM: %d%% (%d/%d MB) | Disco: %d%% (%d/%d GB)\n• Clique: Monitor do Sistema\n• Botão Direito: Monitor htop\n• Clique do Meio: Monitor btop", cpu.percent, mem.percent, mem.used_mb or 0, mem.total_mb or 0, disk.percent, disk.used_gb or 0, disk.total_gb or 0)

    local hw_children = {
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 3,
            children = {
                Zenith.Text({ text = "", font_size = 12, color = cpu_color }),
                Zenith.Text({ text = cpu_binding, font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),
        Zenith.Box({
            width = 1,
            height = 12,
            background = Zenith.hex(theme.outline_variant or theme.outline, 60),
            margin = { x = 2, y = 0 },
            children = {},
        }),
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 3,
            children = {
                Zenith.Text({ text = "󰘚", font_size = 12, color = mem_color }),
                Zenith.Text({ text = mem_binding, font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }),
    }

    if screen_w >= 1200 and disk.total_gb > 0 then
        table.insert(hw_children, Zenith.Box({
            width = 1,
            height = 12,
            background = Zenith.hex(theme.outline_variant or theme.outline, 60),
            margin = { x = 2, y = 0 },
            children = {},
        }))
        table.insert(hw_children, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 3,
            children = {
                Zenith.Text({ text = "󰋊", font_size = 12, color = disk_color }),
                Zenith.Text({ text = string.format("%d%%", disk.percent), font_size = 11, color = Zenith.hex(theme.on_surface) }),
            }
        }))
    end

    return Pill({
        height = 26,
        border_radius = 13,
        padding = { x = pad_x, y = 2 },
        gap = 5,
        tooltip = tip,
        on_click = (props and props.on_click) or "popup:toggle:SystemMonitorPopup",
        on_right_click = (props and props.on_right_click) or "cmd:foot -e htop &",
        on_middle_click = (props and props.on_middle_click) or "cmd:foot -e btop &",
        children = hw_children,
    })
end

return Hardware
