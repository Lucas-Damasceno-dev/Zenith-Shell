--!strict
-- Zenith Desktop Shell — Inir-Style Unified Settings Design System & Primitives
-- Provides pixel-accurate recreation of the Inir Shell settings UI architecture

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")
local Button = Zenith.import("core/ui/button")
local Switch = Zenith.import("core/ui/switch")
local Slider = Zenith.import("core/ui/slider")

local Components = {}

-- Layered color palette matching Inir's M3/Zzz layered hierarchy
function Components.get_palette()
    local t = Theme.get()
    return {
        colLayer0 = Zenith.hex(t.surface_container_lowest or t.background or "#0d0f14"),
        colLayer1 = Zenith.hex(t.surface_container_low or t.surface or "#161922"),
        colLayer2 = Zenith.hex(t.surface_container or "#1e222e"),
        colLayer3 = Zenith.hex(t.surface_container_high or "#262b3a"),
        colPrimary = Zenith.hex(t.primary or "#7c4dff"),
        colPrimaryContainer = Zenith.hex(t.primary_container or "#392b63", 220),
        colOnPrimaryContainer = Zenith.hex(t.on_primary_container or "#eaddff"),
        colOnSurface = Zenith.hex(t.on_surface or "#e6e8f0"),
        colSubtext = Zenith.hex(t.on_surface_variant or "#98a0b3"),
        colBorderSubtle = Zenith.hex(t.outline_variant or t.outline or "#ffffff", 35),
        colBorderMuted = Zenith.hex(t.outline or "#ffffff", 70),
        colAccent = Zenith.hex(t.primary or "#7c4dff"),
    }
end

-- 1. Master Top Header Bar (Identity + Pill Search + Quick Actions)
function Components.Header(props: {
    active_page_name: string?,
    search_query: string?,
    results_count: number?,
    easy_mode: boolean?,
})
    local pal = Components.get_palette()
    local search_text = props.search_query or ""
    local has_search = string.len(search_text) > 0
    local is_easy = props.easy_mode or Store.get("settingsEasyMode", false)

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        height = 52,
        padding = { horizontal = 12, vertical = 6 },
        children = {
            -- Left Identity Block (Avatar circle + Title + Username)
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 10,
                width = 210,
                cursor = "pointer",
                on_click = "settings:page:0",
                children = {
                    -- Circular Avatar with 1px primary border and edit badge
                    Zenith.Box({
                        width = 36,
                        height = 36,
                        border_radius = 18,
                        background = pal.colLayer2,
                        border_width = 1.5,
                        border_color = pal.colPrimary,
                        align_items = "center",
                        justify_content = "center",
                        children = {
                            Zenith.Text({
                                text = "󰀉",
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 18,
                                color = pal.colPrimary,
                            }),
                        },
                    }),
                    -- Identity Labels
                    Zenith.Box({
                        direction = "column",
                        gap = 1,
                        children = {
                            Zenith.Text({
                                text = "Configurações",
                                font_family = "Inter",
                                font_size = 14,
                                font_weight = "bold",
                                color = pal.colOnSurface,
                            }),
                            Zenith.Text({
                                text = "lucas@meu-nixos",
                                font_family = "Inter",
                                font_size = 11,
                                color = pal.colSubtext,
                            }),
                        },
                    }),
                },
            }),

            -- Center Pill Search Bar
            Zenith.Box({
                direction = "row",
                align_items = "center",
                width = 380,
                height = 36,
                padding = { horizontal = 12 },
                gap = 8,
                border_radius = 9999,
                background = pal.colLayer2,
                border_width = 1,
                border_color = if has_search then pal.colPrimary else pal.colBorderSubtle,
                children = {
                    Zenith.Text({
                        text = if has_search then "󰍉" else "󰍉",
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 14,
                        color = if has_search then pal.colPrimary else pal.colSubtext,
                    }),
                    Zenith.TextInput({
                        id = "settings_search_input",
                        placeholder = "Pesquisar configurações... (Ctrl+F)",
                        text = search_text,
                        color = pal.colOnSurface,
                        font_size = 12,
                        width = 280,
                        on_change = "settings:search:change",
                    }),
                    if has_search then
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 6,
                            children = {
                                Zenith.Box({
                                    padding = { horizontal = 6, vertical = 2 },
                                    border_radius = 9999,
                                    background = pal.colPrimaryContainer,
                                    children = {
                                        Zenith.Text({
                                            text = tostring(props.results_count or 1),
                                            font_family = "Inter",
                                            font_size = 10,
                                            font_weight = "bold",
                                            color = pal.colOnPrimaryContainer,
                                        }),
                                    },
                                }),
                                Zenith.Box({
                                    cursor = "pointer",
                                    on_click = "settings:search:clear",
                                    children = {
                                        Zenith.Text({
                                            text = "󰅖",
                                            font_family = "JetBrainsMono Nerd Font",
                                            font_size = 12,
                                            color = pal.colSubtext,
                                        }),
                                    },
                                }),
                            },
                        })
                    else
                        Zenith.Box({ width = 0, height = 0 }),
                },
            }),

            -- Right Quick Action Tool Pills
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 6,
                children = {
                    -- Easy / Advanced Mode Toggle
                    Zenith.Box({
                        width = 32,
                        height = 32,
                        border_radius = 9999,
                        background = if is_easy then pal.colPrimaryContainer else pal.colLayer2,
                        border_width = 1,
                        border_color = if is_easy then pal.colPrimary else pal.colBorderSubtle,
                        align_items = "center",
                        justify_content = "center",
                        cursor = "pointer",
                        tooltip = if is_easy then "Modo Fácil (Essenciais)" else "Modo Avançado (Todas Opções)",
                        on_click = "storage:toggle:settingsEasyMode",
                        children = {
                            Zenith.Text({
                                text = if is_easy then "󰑮" else "󰒓",
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 14,
                                color = if is_easy then pal.colPrimary else pal.colSubtext,
                            }),
                        },
                    }),
                    -- Lock Screen Action
                    Zenith.Box({
                        width = 32,
                        height = 32,
                        border_radius = 9999,
                        background = pal.colLayer2,
                        border_width = 1,
                        border_color = pal.colBorderSubtle,
                        align_items = "center",
                        justify_content = "center",
                        cursor = "pointer",
                        tooltip = "Bloquear Tela",
                        on_click = "lock",
                        children = {
                            Zenith.Text({
                                text = "󰌾",
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 14,
                                color = pal.colSubtext,
                            }),
                        },
                    }),
                    -- Close Action
                    Zenith.Box({
                        width = 32,
                        height = 32,
                        border_radius = 9999,
                        background = pal.colLayer2,
                        border_width = 1,
                        border_color = pal.colBorderSubtle,
                        align_items = "center",
                        justify_content = "center",
                        cursor = "pointer",
                        tooltip = "Fechar Configurações (Esc)",
                        on_click = "popup:close",
                        children = {
                            Zenith.Text({
                                text = "󰅖",
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 14,
                                color = pal.colSubtext,
                            }),
                        },
                    }),
                },
            }),
        },
    })
end

-- 2. Page Header Banner (Icon Squircle + Title + Subtitle Description + Divider)
function Components.PageBanner(props: {
    icon: string,
    title: string,
    subtitle: string,
})
    local pal = Components.get_palette()

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 10,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 12,
                width = "100%",
                children = {
                    Zenith.Box({
                        width = 38,
                        height = 38,
                        border_radius = 12,
                        background = pal.colPrimaryContainer,
                        border_width = 1,
                        border_color = pal.colPrimary,
                        align_items = "center",
                        justify_content = "center",
                        children = {
                            Zenith.Text({
                                text = props.icon,
                                font_family = "JetBrainsMono Nerd Font",
                                font_size = 18,
                                color = pal.colPrimary,
                            }),
                        },
                    }),
                    Zenith.Box({
                        direction = "column",
                        gap = 2,
                        children = {
                            Zenith.Text({
                                text = props.title,
                                font_family = "Inter",
                                font_size = 18,
                                font_weight = "bold",
                                color = pal.colOnSurface,
                            }),
                            Zenith.Text({
                                text = props.subtitle,
                                font_family = "Inter",
                                font_size = 12,
                                color = pal.colSubtext,
                            }),
                        },
                    }),
                },
            }),
            -- Divider line
            Zenith.Box({
                width = "100%",
                height = 1,
                background = pal.colBorderSubtle,
            }),
        },
    })
end

-- 3. Task Navigator Pill Chips (Sub-sections bar like Inir SettingsTaskNavigator)
export type TaskOption = {
    id: string,
    name: string,
    icon: string?,
}

function Components.TaskNavigator(props: {
    tasks: { TaskOption },
    active_task: string,
    on_select: ((task_id: string) -> ())?,
})
    local pal = Components.get_palette()
    local chips: { any } = {}

    for _, t in ipairs(props.tasks) do
        local is_active = t.id == props.active_task
        table.insert(chips, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            height = 28,
            padding = { horizontal = 12 },
            border_radius = 9999,
            cursor = "pointer",
            background = if is_active then pal.colPrimaryContainer else pal.colLayer2,
            border_width = 1,
            border_color = if is_active then pal.colPrimary else pal.colBorderSubtle,
            on_click = "settings:task:" .. t.id,
            children = {
                if t.icon then
                    Zenith.Text({
                        text = t.icon,
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 12,
                        color = if is_active then pal.colPrimary else pal.colSubtext,
                    })
                else
                    Zenith.Box({ width = 0, height = 0 }),
                Zenith.Text({
                    text = t.name,
                    font_family = "Inter",
                    font_size = 11,
                    font_weight = if is_active then "semibold" else "normal",
                    color = if is_active then pal.colOnPrimaryContainer else pal.colSubtext,
                }),
            },
        }))
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 8,
        width = "100%",
        padding = { vertical = 2 },
        children = chips,
    })
end

-- 4. Inir Grouped Card Section Container
function Components.CardSection(props: {
    title: string?,
    icon: string?,
    badge: string?,
    children: { any }?,
})
    local pal = Components.get_palette()

    local header_elements: { any } = {}
    if props.icon or props.title then
        local header_row: { any } = {}
        if props.icon then
            table.insert(header_row, Zenith.Text({
                text = props.icon,
                font_family = "JetBrainsMono Nerd Font",
                font_size = 14,
                color = pal.colPrimary,
            }))
        end
        if props.title then
            table.insert(header_row, Zenith.Text({
                text = props.title,
                font_family = "Inter",
                font_size = 13,
                font_weight = "bold",
                color = pal.colOnSurface,
            }))
        end
        if props.badge then
            table.insert(header_row, Zenith.Box({
                padding = { horizontal = 6, vertical = 2 },
                border_radius = 6,
                background = pal.colPrimaryContainer,
                children = {
                    Zenith.Text({
                        text = props.badge,
                        font_family = "Inter",
                        font_size = 10,
                        font_weight = "bold",
                        color = pal.colOnPrimaryContainer,
                    }),
                },
            }))
        end

        table.insert(header_elements, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 8,
            width = "100%",
            padding = { bottom = 4 },
            children = header_row,
        }))
    end

    local all_children: { any } = {}
    for _, h in ipairs(header_elements) do
        table.insert(all_children, h)
    end
    if props.children then
        for _, c in ipairs(props.children) do
            table.insert(all_children, c)
        end
    end

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 10,
        padding = 14,
        border_radius = 14,
        background = pal.colLayer2,
        border_width = 1,
        border_color = pal.colBorderSubtle,
        children = all_children,
    })
end

-- 5. Switch Row with Icon Badge, Label, Subtitle and Toggle
function Components.SwitchRow(props: {
    icon: string?,
    label: string,
    subtitle: string?,
    checked: boolean,
    on_toggle: any,
})
    local pal = Components.get_palette()

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        padding = { vertical = 4 },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 10,
                children = {
                    if props.icon then
                        Zenith.Box({
                            width = 28,
                            height = 28,
                            border_radius = 8,
                            background = pal.colLayer3,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = props.icon,
                                    font_family = "JetBrainsMono Nerd Font",
                                    font_size = 13,
                                    color = pal.colPrimary,
                                }),
                            },
                        })
                    else
                        Zenith.Box({ width = 0, height = 0 }),
                    Zenith.Box({
                        direction = "column",
                        gap = 1,
                        children = {
                            Zenith.Text({
                                text = props.label,
                                font_family = "Inter",
                                font_size = 13,
                                font_weight = "medium",
                                color = pal.colOnSurface,
                            }),
                            if props.subtitle then
                                Zenith.Text({
                                    text = props.subtitle,
                                    font_family = "Inter",
                                    font_size = 11,
                                    color = pal.colSubtext,
                                })
                            else
                                Zenith.Box({ width = 0, height = 0 }),
                        },
                    }),
                },
            }),
            Switch({
                checked = props.checked,
                on_toggle = props.on_toggle,
            }),
        },
    })
end

-- 6. Slider Row with Icon Badge, Label, Value Pill and Slider Track
function Components.SliderRow(props: {
    icon: string?,
    label: string,
    subtitle: string?,
    value: number,
    min: number,
    max: number,
    step: number?,
    unit: string?,
    on_change: any,
})
    local pal = Components.get_palette()
    local unit_str = props.unit or ""
    local val_display = string.format("%d%s", math.floor(props.value), unit_str)

    return Zenith.Box({
        direction = "column",
        gap = 6,
        width = "100%",
        padding = { vertical = 4 },
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
                        gap = 10,
                        children = {
                            if props.icon then
                                Zenith.Box({
                                    width = 28,
                                    height = 28,
                                    border_radius = 8,
                                    background = pal.colLayer3,
                                    align_items = "center",
                                    justify_content = "center",
                                    children = {
                                        Zenith.Text({
                                            text = props.icon,
                                            font_family = "JetBrainsMono Nerd Font",
                                            font_size = 13,
                                            color = pal.colPrimary,
                                        }),
                                    },
                                })
                            else
                                Zenith.Box({ width = 0, height = 0 }),
                            Zenith.Box({
                                direction = "column",
                                gap = 1,
                                children = {
                                    Zenith.Text({
                                        text = props.label,
                                        font_family = "Inter",
                                        font_size = 13,
                                        font_weight = "medium",
                                        color = pal.colOnSurface,
                                    }),
                                    if props.subtitle then
                                        Zenith.Text({
                                            text = props.subtitle,
                                            font_family = "Inter",
                                            font_size = 11,
                                            color = pal.colSubtext,
                                        })
                                    else
                                        Zenith.Box({ width = 0, height = 0 }),
                                },
                            }),
                        },
                    }),
                    -- Value Chip
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 6,
                        background = pal.colPrimaryContainer,
                        children = {
                            Zenith.Text({
                                text = val_display,
                                font_family = "Inter",
                                font_size = 11,
                                font_weight = "bold",
                                color = pal.colOnPrimaryContainer,
                            }),
                        },
                    }),
                },
            }),
            Slider({
                id = (props :: any).id or (if type(props.on_change) == "string" then props.on_change else nil),
                value = props.value,
                min = props.min,
                max = props.max,
                step = props.step or 1,
                on_change = props.on_change,
            }),
        },
    })
end

-- 7. Segmented Choice Row
export type SegmentOption = {
    id: string,
    label: string,
}

function Components.SegmentedRow(props: {
    icon: string?,
    label: string,
    subtitle: string?,
    options: { SegmentOption },
    selected: string,
    on_change_action_prefix: string,
})
    local pal = Components.get_palette()
    local buttons: { any } = {}

    for _, opt in ipairs(props.options) do
        local is_sel = opt.id == props.selected
        table.insert(buttons, Zenith.Box({
            padding = { horizontal = 10, vertical = 4 },
            border_radius = 8,
            cursor = "pointer",
            background = if is_sel then pal.colPrimaryContainer else pal.colLayer3,
            border_width = 1,
            border_color = if is_sel then pal.colPrimary else pal.colBorderSubtle,
            on_click = props.on_change_action_prefix .. ":" .. opt.id,
            children = {
                Zenith.Text({
                    text = opt.label,
                    font_family = "Inter",
                    font_size = 11,
                    font_weight = if is_sel then "bold" else "normal",
                    color = if is_sel then pal.colOnPrimaryContainer else pal.colSubtext,
                }),
            },
        }))
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        padding = { vertical = 4 },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 10,
                children = {
                    if props.icon then
                        Zenith.Box({
                            width = 28,
                            height = 28,
                            border_radius = 8,
                            background = pal.colLayer3,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = props.icon,
                                    font_family = "JetBrainsMono Nerd Font",
                                    font_size = 13,
                                    color = pal.colPrimary,
                                }),
                            },
                        })
                    else
                        Zenith.Box({ width = 0, height = 0 }),
                    Zenith.Box({
                        direction = "column",
                        gap = 1,
                        children = {
                            Zenith.Text({
                                text = props.label,
                                font_family = "Inter",
                                font_size = 13,
                                font_weight = "medium",
                                color = pal.colOnSurface,
                            }),
                            if props.subtitle then
                                Zenith.Text({
                                    text = props.subtitle,
                                    font_family = "Inter",
                                    font_size = 11,
                                    color = pal.colSubtext,
                                })
                            else
                                Zenith.Box({ width = 0, height = 0 }),
                        },
                    }),
                },
            }),
            Zenith.Box({
                direction = "row",
                gap = 6,
                children = buttons,
            }),
        },
    })
end

-- 8. Action Button Row
function Components.ActionRow(props: {
    icon: string?,
    label: string,
    subtitle: string?,
    button_label: string,
    button_icon: string?,
    variant: string?,
    on_click: any,
})
    local pal = Components.get_palette()

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = "100%",
        padding = { vertical = 4 },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 10,
                children = {
                    if props.icon then
                        Zenith.Box({
                            width = 28,
                            height = 28,
                            border_radius = 8,
                            background = pal.colLayer3,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = props.icon,
                                    font_family = "JetBrainsMono Nerd Font",
                                    font_size = 13,
                                    color = pal.colPrimary,
                                }),
                            },
                        })
                    else
                        Zenith.Box({ width = 0, height = 0 }),
                    Zenith.Box({
                        direction = "column",
                        gap = 1,
                        children = {
                            Zenith.Text({
                                text = props.label,
                                font_family = "Inter",
                                font_size = 13,
                                font_weight = "medium",
                                color = pal.colOnSurface,
                            }),
                            if props.subtitle then
                                Zenith.Text({
                                    text = props.subtitle,
                                    font_family = "Inter",
                                    font_size = 11,
                                    color = pal.colSubtext,
                                })
                            else
                                Zenith.Box({ width = 0, height = 0 }),
                        },
                    }),
                },
            }),
            Button({
                label = props.button_label,
                icon = props.button_icon,
                variant = props.variant or "tonal",
                size = "sm",
                on_click = props.on_click,
            }),
        },
    })
end

-- 9. Thin Divider
function Components.Divider()
    local pal = Components.get_palette()
    return Zenith.Box({
        width = "100%",
        height = 1,
        background = pal.colBorderSubtle,
    })
end

return Components
