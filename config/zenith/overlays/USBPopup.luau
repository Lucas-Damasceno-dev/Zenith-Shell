--!strict
-- Zenith-Shell (Engine v2) - USB Devices & Removable Media Management Overlay
-- 1:1 Parity with Quickshell USBPopup.qml (Partition list, mount/unmount, eject, Thunar open)

local theme = Zenith.Theme()

export type UsbPartition = {
    name: string,
    parentDisk: string?,
    label: string?,
    model: string?,
    size: string?,
    type: string?,
    fstype: string?,
    mountpoint: string?,
    mounted: boolean?,
    fsused: string?,
    fsavail: string?,
    fsusepct: string?,
}

-- Discover connected removable USB storage devices
local devices: { UsbPartition } = {}

-- 1. Try reading from Zenith.Storage
if Zenith.Storage and Zenith.Storage.get then
    local raw_devs = Zenith.Storage.get("usb_devices", nil)
    if type(raw_devs) == "table" then
        for _, dev in ipairs(raw_devs) do
            if type(dev) == "table" and dev.name then
                local is_mounted = (dev.mounted == true) or (dev.mountpoint ~= nil and dev.mountpoint ~= "")
                table.insert(devices, {
                    name = tostring(dev.name),
                    parentDisk = if dev.parentDisk then tostring(dev.parentDisk) else nil,
                    label = if dev.label then tostring(dev.label) else nil,
                    model = if dev.model then tostring(dev.model) else nil,
                    size = if dev.size then tostring(dev.size) else "",
                    type = if dev.type then tostring(dev.type) else "part",
                    fstype = if dev.fstype then tostring(dev.fstype) else "",
                    mountpoint = if dev.mountpoint and dev.mountpoint ~= "" then tostring(dev.mountpoint) else nil,
                    mounted = is_mounted,
                    fsused = if dev.fsused then tostring(dev.fsused) else nil,
                    fsavail = if dev.fsavail then tostring(dev.fsavail) else nil,
                    fsusepct = if dev.fsusepct then tostring(dev.fsusepct) else nil,
                })
            end
        end
    end
end

-- 2. Fallback: Parse /proc/mounts for active removable / media mounts if storage is empty
if #devices == 0 then
    pcall(function()
        local f = io.open("/proc/mounts", "r")
        if f then
            for line in f:lines() do
                local dev_node, mnt, fstype = line:match("^(%S+)%s+(%S+)%s+(%S+)")
                if dev_node and mnt and (mnt:find("/run/media/") or mnt:find("/media/") or mnt:find("/mnt/")) then
                    local dev_name = dev_node:match("/dev/(.+)$") or dev_node
                    local label = mnt:match("/([^/]+)$") or dev_name
                    table.insert(devices, {
                        name = dev_name,
                        parentDisk = dev_name:gsub("%d+$", ""),
                        label = label,
                        model = "Dispositivo Removível",
                        size = "",
                        type = "part",
                        fstype = fstype,
                        mountpoint = mnt,
                        mounted = true,
                        fsused = nil,
                        fsavail = nil,
                        fsusepct = nil,
                    })
                end
            end
            f:close()
        end
    end)
end

local total_devices = #devices
local max_visible = 5
local scroll_offset = _G.__usb_scroll or 0
if scroll_offset > math.max(0, total_devices - max_visible) then
    scroll_offset = math.max(0, total_devices - max_visible)
end
if scroll_offset < 0 then
    scroll_offset = 0
end

local start_idx = scroll_offset + 1
local end_idx = math.min(total_devices, start_idx + max_visible - 1)

local function scroll_up()
    _G.__usb_scroll = math.max(0, (_G.__usb_scroll or 0) - 1)
end

local function scroll_down()
    local max_s = math.max(0, total_devices - max_visible)
    _G.__usb_scroll = math.min(max_s, (_G.__usb_scroll or 0) + 1)
end

-- Build Device Card Nodes
local device_cards = {}
if total_devices == 0 then
    table.insert(device_cards, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        padding = { x = 20, y = 28 },
        gap = 10,
        children = {
            Zenith.Text({
                text = "󰕓",
                font_size = 36,
                color = Zenith.hex(theme.outline, 90),
            }),
            Zenith.Text({
                text = "Nenhum dispositivo USB conectado",
                font_size = 12,
                font_weight = "medium",
                color = Zenith.hex(theme.on_surface, 180),
            }),
            Zenith.Text({
                text = "Conecte um pendrive ou disco externo para gerenciar",
                font_size = 10,
                color = Zenith.hex(theme.outline, 160),
            }),
        }
    }))
else
    for i = start_idx, end_idx do
        local dev = devices[i]
        if not dev then break end

        local is_mounted = dev.mounted == true
        local display_title = dev.label or dev.model or dev.name
        if #display_title > 24 then
            display_title = display_title:sub(1, 21) .. "..."
        end

        local subtitle_info = dev.size or ""
        if dev.fstype and #dev.fstype > 0 then
            subtitle_info = (if #subtitle_info > 0 then subtitle_info .. " (" .. dev.fstype .. ")" else dev.fstype)
        end
        if is_mounted and dev.mountpoint then
            subtitle_info = subtitle_info .. " • " .. dev.mountpoint
        else
            subtitle_info = subtitle_info .. " • [Desmontado]"
        end

        -- Capacity percentage and progress bar
        local pct_int = 0
        if dev.fsusepct and #dev.fsusepct > 0 then
            local num = tonumber(dev.fsusepct:gsub("%%", ""))
            if num then pct_int = math.clamp(num, 0, 100) end
        end

        local meter_color = if pct_int >= 90 then (theme.red or "#f38ba8")
            elseif pct_int >= 75 then (theme.peach or "#fab387")
            else theme.primary

        local storage_meter_node = if is_mounted and pct_int > 0 then
            Zenith.Box({
                direction = "column",
                gap = 2,
                children = {
                    Zenith.Box({
                        height = 4,
                        border_radius = 2,
                        background = Zenith.rgba(255, 255, 255, 25),
                        children = {
                            Zenith.Box({
                                width = tostring(pct_int) .. "%",
                                height = 4,
                                border_radius = 2,
                                background = Zenith.hex(meter_color),
                            })
                        }
                    }),
                    Zenith.Text({
                        text = (if dev.fsavail and dev.size and #dev.fsavail > 0 then
                            string.format("Livre: %s / %s (%d%% usado)", dev.fsavail, dev.size, pct_int)
                        else
                            string.format("Capacidade: %d%% usado", pct_int)),
                        font_size = 8,
                        color = Zenith.hex(theme.outline),
                    })
                }
            })
        else
            nil

        -- Action Buttons
        local action_buttons = {}

        -- 1. Open in Thunar (File Manager)
        if is_mounted and dev.mountpoint and #dev.mountpoint > 0 then
            table.insert(action_buttons, Zenith.Box({
                width = 28,
                height = 28,
                border_radius = 8,
                align_items = "center",
                justify_content = "center",
                background = Zenith.hex(theme.surface_container_highest or theme.surface_container, 140),
                border_color = Zenith.hex(theme.outline, 40),
                border_width = 1,
                tooltip = "Abrir no Thunar (" .. dev.mountpoint .. ")",
                on_click = "cmd:thunar '" .. dev.mountpoint .. "' &",
                children = {
                    Zenith.Text({
                        text = "󰝰",
                        font_size = 12,
                        color = Zenith.hex(theme.primary),
                    })
                }
            }))
        end

        -- 2. Mount / Unmount button
        local mount_action = if is_mounted
            then "cmd:udisksctl unmount -b /dev/" .. dev.name .. " &"
            else "cmd:udisksctl mount -b /dev/" .. dev.name .. " &"

        local mount_icon = if is_mounted then "󰕑" else "󰕒"
        local mount_tooltip = if is_mounted then "Desmontar partição " .. dev.name else "Montar partição " .. dev.name

        table.insert(action_buttons, Zenith.Box({
            width = 28,
            height = 28,
            border_radius = 8,
            align_items = "center",
            justify_content = "center",
            background = is_mounted and Zenith.hex(theme.primary, 35) or Zenith.hex(theme.surface_container_highest or theme.surface_container, 140),
            border_color = is_mounted and Zenith.hex(theme.primary) or Zenith.hex(theme.outline, 40),
            border_width = 1,
            tooltip = mount_tooltip,
            on_click = mount_action,
            children = {
                Zenith.Text({
                    text = mount_icon,
                    font_size = 12,
                    color = is_mounted and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface),
                })
            }
        }))

        -- 3. Eject / Power-off drive button
        local eject_target = dev.parentDisk or dev.name
        table.insert(action_buttons, Zenith.Box({
            width = 28,
            height = 28,
            border_radius = 8,
            align_items = "center",
            justify_content = "center",
            background = Zenith.hex(theme.red or "#f38ba8", 25),
            border_color = Zenith.hex(theme.red or "#f38ba8", 80),
            border_width = 1,
            tooltip = "Ejetar unidade com segurança (" .. eject_target .. ")",
            on_click = "cmd:bash config/quickshell/scripts/system/usb_devices.sh --eject " .. dev.name .. " &",
            children = {
                Zenith.Text({
                    text = "󰃚",
                    font_size = 12,
                    color = Zenith.hex(theme.red or "#f38ba8"),
                })
            }
        }))

        -- Card Assembly
        table.insert(device_cards, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 10 },
            border_radius = 12,
            background = is_mounted and Zenith.hex(theme.surface_container_high or theme.surface_container, 120) or Zenith.hex(theme.surface_container, 80),
            border_color = is_mounted and Zenith.hex(theme.primary, 60) or Zenith.hex(theme.outline_variant or theme.outline, 35),
            border_width = 1,
            gap = 10,
            children = {
                -- Icon Badge
                Zenith.Box({
                    width = 38,
                    height = 38,
                    border_radius = 10,
                    align_items = "center",
                    justify_content = "center",
                    background = is_mounted and Zenith.hex(theme.primary, 35) or Zenith.hex(theme.surface_container_highest or theme.surface_container, 100),
                    children = {
                        Zenith.Text({
                            text = if dev.type == "disk" then "󰋊" else "󰡀",
                            font_size = 18,
                            color = is_mounted and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                        })
                    }
                }),

                -- Center details
                Zenith.Box({
                    direction = "column",
                    align_items = "stretch",
                    justify_content = "center",
                    gap = 2,
                    flex_grow = 1,
                    children = {
                        Zenith.Text({
                            text = display_title,
                            font_size = 11,
                            font_weight = "bold",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = subtitle_info,
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                        storage_meter_node,
                    }
                }),

                -- Action Buttons Group
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = action_buttons,
                })
            }
        }))
    end
end

local visible_count = if total_devices == 0 then 1 else (end_idx - start_idx + 1)
local win_height = if total_devices == 0 then 210 else math.min(480, math.max(180, 110 + (visible_count * 74)))

local section_header = if total_devices > max_visible
    then string.format("DISPOSITIVOS REMOVÍVEIS (%d–%d de %d • role para navegar)", start_idx, end_idx, total_devices)
    else string.format("DISPOSITIVOS REMOVÍVEIS (%d)", total_devices)

return Zenith.Window({
    direction = "column",
    align_items = "stretch",
    width = 360,
    height = win_height,
    padding = { x = 16, y = 14 },
    gap = 10,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 18,
    on_scroll_up = scroll_up,
    on_scroll_down = scroll_down,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header: Title + Eject All + Refresh + Close
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰕓 Dispositivos USB",
                    font_size = 13,
                    font_weight = "medium",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),

                -- Eject All button (visible when there are devices)
                Zenith.Box({
                    width = 26,
                    height = 26,
                    border_radius = 6,
                    align_items = "center",
                    justify_content = "center",
                    background = Zenith.hex(theme.surface_container),
                    tooltip = "Desmontar e ejetar todos os dispositivos",
                    on_click = "cmd:udiskie-umount -a &",
                    children = {
                        Zenith.Text({
                            text = "󰃚",
                            font_size = 11,
                            color = Zenith.hex(theme.red or "#f38ba8"),
                        })
                    }
                }),

                Zenith.Box({ width = 6 }),

                -- Refresh button
                Zenith.Box({
                    width = 26,
                    height = 26,
                    border_radius = 6,
                    align_items = "center",
                    justify_content = "center",
                    background = Zenith.hex(theme.surface_container),
                    tooltip = "Atualizar lista",
                    on_click = "cmd:bash config/quickshell/scripts/system/usb_devices.sh --json &",
                    children = {
                        Zenith.Text({
                            text = "󰑐",
                            font_size = 11,
                            color = Zenith.hex(theme.on_surface),
                        })
                    }
                }),

                Zenith.Box({ width = 6 }),

                -- Close ESC button
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 6,
                    background = Zenith.hex(theme.surface_container),
                    tooltip = "Fechar popup (ESC)",
                    on_click = "popup:close",
                    children = {
                        Zenith.Text({ text = "ESC", font_size = 9, color = Zenith.hex(theme.on_surface) }),
                    }
                }),
            }
        }),

        -- Devices Section Subheader
        Zenith.Text({
            text = section_header,
            font_size = 9,
            font_weight = "bold",
            color = Zenith.hex(theme.outline),
        }),

        -- Device Cards List
        Zenith.Box({
            direction = "column",
            align_items = "stretch",
            gap = 6,
            flex_grow = 1,
            on_scroll_up = scroll_up,
            on_scroll_down = scroll_down,
            children = device_cards,
        }),
    }
})
