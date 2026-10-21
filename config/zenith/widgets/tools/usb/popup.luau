--!strict
-- Zenith-Shell: USB Devices & Storage Manager Popup

local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function USBPopup()
    local theme = Theme.get()
    local raw_devs = {}
    if Zenith.Storage and Zenith.Storage.get then
        local devs = Zenith.Storage.get("usb_devices", nil)
        if type(devs) == "table" then
            raw_devs = devs
        end
    end

    local dev_cards = {}
    for idx, d in ipairs(raw_devs) do
        local name = d.name or d.label or string.format("Dispositivo USB #%d", idx)
        local mount = d.mountpoint or "Não montado"
        local size_str = d.size or ""

        table.insert(dev_cards, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { horizontal = 10, vertical = 8 },
            border_radius = 8,
            background = Zenith.hex(theme.surface_container, 140),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 40),
            border_width = 1,
            children = {
                Zenith.Text({
                    text = "󰕓",
                    font_size = 16,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ width = 8 }),
                Zenith.Box({
                    direction = "column",
                    flex_grow = 1,
                    gap = 2,
                    children = {
                        Zenith.Text({
                            text = name,
                            font_size = 11,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = mount .. (if #size_str > 0 then " • " .. size_str else ""),
                            font_size = 9,
                            color = Zenith.hex(theme.on_surface_variant or theme.outline),
                        }),
                    }
                }),
                Zenith.Box({
                    padding = { horizontal = 6, vertical = 3 },
                    border_radius = 4,
                    background = Zenith.hex(theme.error or "#f38ba8", 30),
                    cursor = "pointer",
                    on_click = string.format("cmd:udiskie-umount %s &", d.device or ""),
                    children = {
                        Zenith.Text({ text = "Ejetar", font_size = 9, color = Zenith.hex(theme.error or "#f38ba8") }),
                    }
                })
            }
        }))
    end

    if #dev_cards == 0 then
        table.insert(dev_cards, Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            height = 100,
            children = {
                Zenith.Text({
                    text = "󰕓 Nenhuma mídia USB conectada",
                    font_size = 11,
                    color = Zenith.hex(theme.outline_variant or theme.outline),
                }),
            }
        }))
    end

    return Zenith.Box({
        direction = "column",
        width = 320,
        height = 260,
        padding = { horizontal = 16, vertical = 14 },
        gap = 10,
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
                        text = "󰕓 Dispositivos USB",
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
                gap = 6,
                flex_grow = 1,
                children = dev_cards,
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "flex_end",
                children = {
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 4 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container, 160),
                        cursor = "pointer",
                        on_click = "cmd:udiskie-umount -a &",
                        children = {
                            Zenith.Text({
                                text = "Ejetar Todos com Segurança",
                                font_size = 10,
                                color = Zenith.hex(theme.primary),
                            })
                        }
                    })
                }
            })
        }
    })
end

return USBPopup
