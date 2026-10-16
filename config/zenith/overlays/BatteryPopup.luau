--!strict
-- Zenith-Shell (Engine v2) - Battery & Power Profile Overlay
-- 1:1 Parity with Quickshell BatteryPopup (Battery Stats, Health, Caffeine & Power Profiles)

local theme = Zenith.Theme()
local Store = Zenith.import("settings_store")
local battery = Zenith.Services.battery()

-- 1. Sincronização em tempo real do Modo Caffeine com o sistema
local caffeine_active = false
pcall(function()
    local uid = os.getenv("UID") or "1000"
    local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. uid)
    local pid_file = runtime_dir .. "/quickshell/quickshell-caffeine.pid"
    local f = io.open(pid_file, "r")
    if f then
        local pid_str = f:read("*a")
        f:close()
        if pid_str and #pid_str > 0 then
            local pid = tonumber(pid_str:match("%d+"))
            if pid and pid > 0 then
                local pf = io.open("/proc/" .. pid .. "/cmdline", "r")
                if pf then
                    pf:close()
                    caffeine_active = true
                end
            end
        end
    end
end)

if not caffeine_active then
    if Zenith.Storage and Zenith.Storage.get then
        local st_val = Zenith.Storage.get("batteryCaffeineActive", nil)
        if st_val ~= nil then
            caffeine_active = (st_val == true or st_val == "true" or st_val == 1)
        else
            caffeine_active = Store.get("batteryCaffeineActive") or false
        end
    else
        caffeine_active = Store.get("batteryCaffeineActive") or false
    end
end

-- 2. Sincronização do Limite de Carga (80% Smart Charge) com o hardware/kernel
local limit_active = false
pcall(function()
    local f = io.open("/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode", "r")
    if f then
        local val = f:read("*a")
        f:close()
        if val and val:match("1") then
            limit_active = true
        end
    end
end)

if not limit_active then
    if Zenith.Storage and Zenith.Storage.get then
        local st_lim = Zenith.Storage.get("batteryLimitActive", nil)
        if st_lim ~= nil then
            limit_active = (st_lim == true or st_lim == "true" or st_lim == 1)
        else
            limit_active = Store.get("batteryLimitActive") or false
        end
    else
        limit_active = Store.get("batteryLimitActive") or false
    end
end

local charge_limit_threshold = 80
if Zenith.Storage and Zenith.Storage.get then
    local st_thresh = Zenith.Storage.get("batteryLimitThreshold", nil)
    if type(st_thresh) == "number" then
        charge_limit_threshold = st_thresh
    end
end
if charge_limit_threshold == 80 and Store and Store.get then
    local st_saved = Store.get("batteryLimitThreshold")
    if type(st_saved) == "number" then
        charge_limit_threshold = st_saved
    end
end

-- 3. Detecção e controle de Perfis de Energia (power-profiles-daemon)
local power_profile = "balanced"
if Zenith.Services.power_profile then
    power_profile = Zenith.Services.power_profile()
elseif Zenith.Services.PowerProfile then
    power_profile = Zenith.Services.PowerProfile()
elseif Store and Store.get then
    power_profile = Store.get("batteryPowerProfile") or "balanced"
end
local current_prof = string.lower(power_profile or "balanced")

-- 4. Controles de brilho e iluminação
local brightness_val = (Zenith.Services.Brightness and Zenith.Services.Brightness().percent)
    or (Zenith.Storage and Zenith.Storage.get and Zenith.Storage.get("brightness", nil))
    or Store.get("brightness")
    or 100

local night_light_val = (Zenith.Storage and Zenith.Storage.get and Zenith.Storage.get("nightLightTemp", nil))
    or Store.get("nightLightTemp")
    or 4000

-- 5. Estatísticas da Bateria e Hardware
local bat_pct = 100
local is_charging = false
local bat_status = "Desconhecido"
local time_remaining_str = ""

if battery then
    bat_pct = battery.percentage or 100
    is_charging = battery.is_charging or false
    bat_status = battery.status or (if is_charging then "Carregando" else "Descarregando")
    if battery.time_remaining and #battery.time_remaining > 0 then
        time_remaining_str = " • " .. battery.time_remaining
    end
end

-- Telemetria estendida: Ciclos, Saúde, Modelo, Uptime
local cycle_count = -1
local health_pct = -1
local model_name = "Bateria do Sistema"
local uptime_str = ""

pcall(function()
    -- Read uptime
    local uf = io.open("/proc/uptime", "r")
    if uf then
        local up_line = uf:read("*l")
        uf:close()
        if up_line then
            local sec_str = up_line:match("^(%d+)")
            local sec = tonumber(sec_str)
            if sec then
                local h = math.floor(sec / 3600)
                local m = math.floor((sec % 3600) / 60)
                uptime_str = string.format("%dh %dm", h, m)
            end
        end
    end

    -- Read sysfs battery details
    local cf = io.open("/sys/class/power_supply/BAT0/cycle_count", "r")
        or io.open("/sys/class/power_supply/BAT1/cycle_count", "r")
    if cf then
        local line = cf:read("*l")
        cf:close()
        if line then cycle_count = tonumber(line) or -1 end
    end

    local mf = io.open("/sys/class/power_supply/BAT0/model_name", "r")
        or io.open("/sys/class/power_supply/BAT1/model_name", "r")
    if mf then
        local line = mf:read("*l")
        mf:close()
        if line and #line > 0 then model_name = line end
    end

    local full_f = io.open("/sys/class/power_supply/BAT0/energy_full", "r")
        or io.open("/sys/class/power_supply/BAT1/energy_full", "r")
        or io.open("/sys/class/power_supply/BAT0/charge_full", "r")
    local des_f = io.open("/sys/class/power_supply/BAT0/energy_full_design", "r")
        or io.open("/sys/class/power_supply/BAT1/energy_full_design", "r")
        or io.open("/sys/class/power_supply/BAT0/charge_full_design", "r")

    if full_f and des_f then
        local full_val = tonumber(full_f:read("*l"))
        local des_val = tonumber(des_f:read("*l"))
        full_f:close()
        des_f:close()
        if full_val and des_val and des_val > 0 then
            health_pct = math.min(100, math.floor((full_val / des_val) * 100))
        end
    end
end)

local bat_icon = "󰁹"
local bat_color = theme.primary
if is_charging then
    bat_icon = "󰂄"
    bat_color = theme.green or "#a6e3a1"
elseif bat_pct > 80 then
    bat_icon = "󰁹"
    bat_color = theme.primary
elseif bat_pct > 50 then
    bat_icon = "󰁿"
    bat_color = theme.primary
elseif bat_pct > 20 then
    bat_icon = "󰁼"
    bat_color = theme.yellow or "#f9e2af"
else
    bat_icon = "󰂃"
    bat_color = theme.error or "#f38ba8"
end

-- Caffeine Command & Callback
local caffeine_action = if caffeine_active
    then "cmd:bash config/quickshell/scripts/system/battery_info.sh caffeine-stop ; zenith-shell --dispatch storage:set:batteryCaffeineActive:false 2>/dev/null &"
    else "cmd:bash config/quickshell/scripts/system/battery_info.sh caffeine-start ; zenith-shell --dispatch storage:set:batteryCaffeineActive:true 2>/dev/null &"

local function on_toggle_caffeine(checked: boolean?)
    local next_val = not caffeine_active
    if Zenith.Storage and Zenith.Storage.set then
        Zenith.Storage.set("batteryCaffeineActive", next_val)
    end
    if Store and Store.set then
        Store.set("batteryCaffeineActive", next_val)
    end
    if next_val then
        Zenith.exec("bash config/quickshell/scripts/system/battery_info.sh caffeine-start")
    else
        Zenith.exec("bash config/quickshell/scripts/system/battery_info.sh caffeine-stop")
    end
end

-- Battery Charge Limit Command & Callback
local limit_toggle_action = if limit_active
    then "cmd:bash config/quickshell/scripts/system/battery_info.sh limit-disable ; zenith-shell --dispatch storage:set:batteryLimitActive:false 2>/dev/null &"
    else "cmd:bash config/quickshell/scripts/system/battery_info.sh limit-enable ; zenith-shell --dispatch storage:set:batteryLimitActive:true 2>/dev/null &"

local function on_toggle_limit(checked: boolean?)
    local next_val = not limit_active
    if Zenith.Storage and Zenith.Storage.set then
        Zenith.Storage.set("batteryLimitActive", next_val)
    end
    if Store and Store.set then
        Store.set("batteryLimitActive", next_val)
    end
    if next_val then
        Zenith.exec("bash config/quickshell/scripts/system/battery_info.sh limit-enable")
    else
        Zenith.exec("bash config/quickshell/scripts/system/battery_info.sh limit-disable")
    end
end

-- Profile Button Component
local function ProfileButton(props: {
    id: string,
    name: string,
    icon: string,
    profile_key: string,
})
    local is_active = (current_prof == props.profile_key)
    local bg = is_active and Zenith.hex(theme.primary, 45) or Zenith.hex(theme.surface_container, 100)
    local border = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline_variant or theme.outline, 40)
    local text_color = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface)

    return Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        flex_grow = 1,
        height = 68,
        gap = 4,
        padding = { x = 6, y = 6 },
        border_radius = 12,
        background = bg,
        border_color = border,
        border_width = 1,
        tooltip = "Definir modo " .. props.name,
        on_click = "power:profile:" .. props.profile_key,
        children = {
            Zenith.Text({
                text = props.icon,
                font_size = 18,
                color = text_color,
            }),
            Zenith.Text({
                text = props.name,
                font_size = 10,
                font_weight = is_active and "medium" or "normal",
                color = text_color,
            }),
            Zenith.Text({
                text = is_active and "● ATIVO" or " ",
                font_size = 8,
                color = is_active and Zenith.hex(theme.primary) or Zenith.rgba(0, 0, 0, 0),
            }),
        }
    })
end

return Zenith.Window({
    direction = "column",
    width = 360,
    height = 580,
    padding = { x = 16, y = 14 },
    gap = 10,
    background = Zenith.hex(theme.surface, 235),
    border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
    border_width = 1,
    border_radius = 18,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 22,
        offset_x = 0,
        offset_y = 8,
    },
    children = {
        -- Header: Title + Close Button
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "󰂄 Bateria & Energia",
                    font_size = 13,
                    font_weight = "medium",
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Box({
                    padding = { x = 7, y = 2 },
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

        -- Main Battery Status Big Card
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 14, y = 12 },
            border_radius = 14,
            background = Zenith.hex(theme.surface_container_high or theme.surface_container, 140),
            border_color = Zenith.hex(bat_color, 80),
            border_width = 1,
            gap = 14,
            children = {
                Zenith.Box({
                    width = 48,
                    height = 48,
                    align_items = "center",
                    justify_content = "center",
                    border_radius = 24,
                    background = Zenith.hex(bat_color, 35),
                    children = {
                        Zenith.Text({
                            text = bat_icon,
                            font_size = 24,
                            color = Zenith.hex(bat_color),
                        }),
                    }
                }),
                Zenith.Box({
                    direction = "column",
                    gap = 2,
                    flex_grow = 1,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            align_items = "baseline",
                            gap = 6,
                            children = {
                                Zenith.Text({
                                    text = string.format("%d%%", bat_pct),
                                    font_size = 20,
                                    font_weight = "bold",
                                    color = Zenith.hex(theme.on_surface),
                                }),
                                Zenith.Text({
                                    text = if is_charging then "(Carregando)" else "(Bateria)",
                                    font_size = 11,
                                    color = Zenith.hex(bat_color),
                                }),
                            }
                        }),
                        Zenith.Text({
                            text = "Status: " .. bat_status .. time_remaining_str,
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                        -- Extra telemetry row: Cycles, Health, Uptime
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 8,
                            children = {
                                if health_pct > 0 then
                                    Zenith.Text({
                                        text = string.format("󰂑 Saúde: %d%%", health_pct),
                                        font_size = 8,
                                        color = Zenith.hex(theme.outline),
                                    })
                                else nil,
                                if cycle_count >= 0 then
                                    Zenith.Text({
                                        text = string.format("󰑑 %d ciclos", cycle_count),
                                        font_size = 8,
                                        color = Zenith.hex(theme.outline),
                                    })
                                else nil,
                                if #uptime_str > 0 then
                                    Zenith.Text({
                                        text = "󰔟 " .. uptime_str,
                                        font_size = 8,
                                        color = Zenith.hex(theme.outline),
                                    })
                                else nil,
                            }
                        })
                    }
                }),
            }
        }),

        -- Power Profiles Section Header
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "PERFIS DE DESEMPENHO",
                    font_size = 10,
                    font_weight = "bold",
                    color = Zenith.hex(theme.outline),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = "power-profiles-daemon",
                    font_size = 9,
                    color = Zenith.hex(theme.outline, 160),
                }),
            }
        }),

        -- Profile Buttons: Power Saver, Balanced, Performance
        Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            children = {
                ProfileButton({
                    id = "btn_power_saver",
                    name = "Economia",
                    icon = "󰌪",
                    profile_key = "power-saver",
                }),
                ProfileButton({
                    id = "btn_balanced",
                    name = "Equilíbrio",
                    icon = "󰓅",
                    profile_key = "balanced",
                }),
                ProfileButton({
                    id = "btn_performance",
                    name = "Desempenho",
                    icon = "󰓅",
                    profile_key = "performance",
                }),
            }
        }),

        -- Screen Filters & Telemetry Section Header
        Zenith.Box({
            direction = "row",
            align_items = "center",
            children = {
                Zenith.Text({
                    text = "CONTROLES DE TELA & BRILHO",
                    font_size = 10,
                    font_weight = "bold",
                    color = Zenith.hex(theme.outline),
                }),
            }
        }),

        -- Brightness Slider Row
        Zenith.Box({
            direction = "column",
            gap = 6,
            padding = { x = 12, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container, 80),
            border_color = Zenith.hex(theme.outline, 30),
            border_width = 1,
            children = {
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    justify_content = "space-between",
                    children = {
                        Zenith.Text({
                            text = "󰃠 Brilho da Tela",
                            font_size = 11,
                            font_weight = "medium",
                            color = Zenith.hex(theme.on_surface),
                        }),
                        Zenith.Text({
                            text = string.format("%d%%", math.floor(brightness_val)),
                            font_size = 10,
                            font_weight = "bold",
                            color = Zenith.hex(theme.primary),
                        }),
                    }
                }),
                Zenith.Slider({
                    id = "battery_brightness_slider",
                    min = 5,
                    max = 100,
                    value = brightness_val,
                    track_height = 6,
                    thumb_radius = 6,
                    track_color = Zenith.rgba(255, 255, 255, 25),
                    active_track_color = Zenith.hex(theme.primary),
                    thumb_color = Zenith.hex("#ffffff"),
                    on_change = function(val: number)
                        local pct = math.floor(val)
                        if Zenith.Services.set_brightness then
                            Zenith.Services.set_brightness(pct)
                        elseif Zenith.Services.SetBrightness then
                            Zenith.Services.SetBrightness(pct)
                        end
                        if Zenith.Storage and Zenith.Storage.set then
                            Zenith.Storage.set("brightness", pct)
                        end
                    end,
                }),
            }
        }),

        -- Interactive Switches & Sliders: Caffeine & Charge Limit 80%
        Zenith.Box({
            direction = "column",
            gap = 6,
            children = {
                -- Caffeine (Inibir suspensão / idle)
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    justify_content = "space-between",
                    padding = { x = 12, y = 8 },
                    border_radius = 10,
                    background = Zenith.hex(theme.surface_container, 80),
                    border_color = Zenith.hex(caffeine_active and theme.primary or theme.outline, 35),
                    border_width = 1,
                    on_click = caffeine_action,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 8,
                            children = {
                                Zenith.Text({
                                    text = "󰅶",
                                    font_size = 14,
                                    color = caffeine_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                                }),
                                Zenith.Box({
                                    direction = "column",
                                    gap = 2,
                                    children = {
                                        Zenith.Text({
                                            text = "Modo Cafeína (Inibir Espera)",
                                            font_size = 11,
                                            font_weight = "medium",
                                            color = Zenith.hex(theme.on_surface),
                                        }),
                                        Zenith.Text({
                                            text = caffeine_active and "Ativo • Bloqueando suspensão do sistema" or "Inativo • Suspensão automática permitida",
                                            font_size = 9,
                                            color = caffeine_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                                        }),
                                    }
                                }),
                            }
                        }),
                        Zenith.Switch({
                            id = "switch_caffeine",
                            checked = caffeine_active,
                            active_color = theme.primary,
                            on_toggle = on_toggle_caffeine,
                        }),
                    }
                }),

                -- Battery Charge Limit 80% (Smart Charge Section with Slider & Toggle)
                Zenith.Box({
                    direction = "column",
                    gap = 6,
                    padding = { x = 12, y = 8 },
                    border_radius = 10,
                    background = Zenith.hex(theme.surface_container, 80),
                    border_color = Zenith.hex(limit_active and theme.primary or theme.outline, 35),
                    border_width = 1,
                    children = {
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            justify_content = "space-between",
                            on_click = limit_toggle_action,
                            children = {
                                Zenith.Box({
                                    direction = "row",
                                    align_items = "center",
                                    gap = 8,
                                    children = {
                                        Zenith.Text({
                                            text = "󰂄",
                                            font_size = 14,
                                            color = limit_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                                        }),
                                        Zenith.Box({
                                            direction = "column",
                                            gap = 2,
                                            children = {
                                                Zenith.Text({
                                                    text = "Limite de Carga (80% Smart Charge)",
                                                    font_size = 11,
                                                    font_weight = "medium",
                                                    color = Zenith.hex(theme.on_surface),
                                                }),
                                                Zenith.Text({
                                                    text = limit_active and "Ativo • Preserva a vida útil e saúde da bateria" or "Desativado • Carrega até 100%",
                                                    font_size = 9,
                                                    color = limit_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline),
                                                }),
                                            }
                                        }),
                                    }
                                }),
                                Zenith.Switch({
                                    id = "switch_charge_limit",
                                    checked = limit_active,
                                    active_color = theme.primary,
                                    on_toggle = on_toggle_limit,
                                }),
                            }
                        }),

                        -- Integrated Threshold Slider
                        Zenith.Box({
                            direction = "column",
                            gap = 3,
                            children = {
                                Zenith.Box({
                                    direction = "row",
                                    align_items = "center",
                                    justify_content = "space-between",
                                    children = {
                                        Zenith.Text({
                                            text = "Limite Alvo de Carga",
                                            font_size = 9,
                                            color = Zenith.hex(theme.outline),
                                        }),
                                        Zenith.Text({
                                            text = string.format("%d%% %s", math.floor(charge_limit_threshold), if charge_limit_threshold == 80 then "(Recomendado)" else ""),
                                            font_size = 9,
                                            font_weight = "bold",
                                            color = Zenith.hex(theme.primary),
                                        }),
                                    }
                                }),
                                Zenith.Slider({
                                    id = "battery_charge_limit_slider",
                                    min = 50,
                                    max = 100,
                                    value = charge_limit_threshold,
                                    track_height = 5,
                                    thumb_radius = 5,
                                    track_color = Zenith.rgba(255, 255, 255, 25),
                                    active_track_color = Zenith.hex(theme.primary),
                                    thumb_color = Zenith.hex("#ffffff"),
                                    on_change = function(val: number)
                                        local pct = math.floor(val)
                                        if Zenith.Storage and Zenith.Storage.set then
                                            Zenith.Storage.set("batteryLimitThreshold", pct)
                                        end
                                        if Store and Store.set then
                                            Store.set("batteryLimitThreshold", pct)
                                        end
                                    end,
                                }),
                            }
                        }),
                    }
                }),
            }
        }),

        -- Quick Action Tile: Economia Noturna / Suspender
        Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 12, y = 8 },
            border_radius = 10,
            background = Zenith.hex(theme.surface_container, 100),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 35),
            border_width = 1,
            tooltip = "Suspender o sistema para economizar energia",
            on_click = "system:suspend",
            children = {
                Zenith.Text({
                    text = "󰒲",
                    font_size = 14,
                    color = Zenith.hex(theme.primary),
                }),
                Zenith.Box({ width = 10 }),
                Zenith.Text({
                    text = "Suspender Sistema",
                    font_size = 11,
                    color = Zenith.hex(theme.on_surface),
                }),
                Zenith.Box({ flex_grow = 1 }),
                Zenith.Text({
                    text = "Modo Baixo Consumo",
                    font_size = 9,
                    color = Zenith.hex(theme.outline),
                }),
            }
        })
    }
})
