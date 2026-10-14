--!strict
-- Zenith-Shell (Engine v2) - Settings & Customization Hub Overlay
-- 1:1 Pixel-faithful replication of the iNiR settings interface in .luau,
-- enriched with advanced controls from the custom Quickshell module.

local Store = Zenith.import("settings_store")
local theme = Zenith.Theme()

local active_page = Store.getActivePage()
local search_query = Store.getSearch()

-- ── 1. Color Tokens & Theme Helpers ─────────────────────────────
local accent_hex = Store.get("accentColor") or theme.primary or "#a8c7fa"
local bg_surface = Zenith.hex("#11141c", 252)
local bg_sidebar = Zenith.hex("#151822", 250)
local bg_card = Zenith.hex("#1c202c", 235)
local border_subtle = Zenith.rgba(255, 255, 255, 18)
local text_main = Zenith.hex("#e2e4ec")
local text_muted = Zenith.hex("#8a90a0")
local text_accent = Zenith.hex(accent_hex)
local chip_active_bg = Zenith.hex(accent_hex)
local chip_active_fg = Zenith.hex("#041e49")
local chip_inactive_bg = Zenith.rgba(255, 255, 255, 12)
local chip_inactive_fg = text_main

-- ── 2. Navigation Registry (1:1 with iNiR & Registry) ───────────
type PageDef = {
    id: number,
    name: string,
    icon: string,
    desc: string,
    category: string,
}

local PAGES: { PageDef } = {
    { id = 0, name = "Quick", icon = "", desc = "Wallpaper, presets & quick toggles", category = "ESSENTIALS" },
    { id = 1, name = "Themes & Style", icon = "", desc = "Colors, typography, borders & physics", category = "APPEARANCE" },
    { id = 2, name = "Wallpaper", icon = "", desc = "Engine, slideshow & effects", category = "APPEARANCE" },
    { id = 3, name = "Bar", icon = "", desc = "Position, auto-hide, modules & tray", category = "SHELL UI" },
    { id = 4, name = "Dock", icon = "", desc = "Dock size, pinned apps & behavior", category = "SHELL UI" },
    { id = 5, name = "Panels", icon = "", desc = "Overview, expose & hot corners", category = "SHELL UI" },
    { id = 6, name = "Dashboard", icon = "", desc = "Welcome hub, greetings & widgets", category = "SHELL UI" },
    { id = 7, name = "Modules", icon = "", desc = "Master switches for shell features", category = "SHELL UI" },
    { id = 8, name = "System", icon = "", desc = "Audio, battery, night light & hyprlock", category = "SYSTEM & CORE" },
    { id = 9, name = "Tools & Capture", icon = "", desc = "Recording, screenshot, OCR & lens", category = "SYSTEM & CORE" },
    { id = 10, name = "Compositor", icon = "", desc = "Hyprland animations, gaps & input", category = "SYSTEM & CORE" },
    { id = 11, name = "Services", icon = "", desc = "Weather, media player & default apps", category = "SYSTEM & CORE" },
    { id = 12, name = "AI & Copilot", icon = "󰚩", desc = "Providers, models, prompt & voice", category = "SYSTEM & CORE" },
    { id = 13, name = "Autostart", icon = "", desc = "Manage startup apps & daemons", category = "SYSTEM & CORE" },
    { id = 14, name = "Advanced", icon = "", desc = "Performance, memory & config JSON", category = "REFERENCE & MAINTENANCE" },
    { id = 15, name = "Shortcuts", icon = "", desc = "Keybindings reference & actions", category = "REFERENCE & MAINTENANCE" },
    { id = 16, name = "About", icon = "", desc = "Zenith Shell info & diagnostics", category = "REFERENCE & MAINTENANCE" },
}

local active_page_def = PAGES[1]
for _, p in ipairs(PAGES) do
    if p.id == active_page then
        active_page_def = p
        break
    end
end

-- ── 3. Modular Card & Row Builders ──────────────────────────────
local function CardContainer(children: { any })
    return Zenith.Box({
        direction = "column",
        width = 720,
        max_width = 720,
        gap = 10,
        padding = { x = 16, y = 14 },
        border_radius = 12,
        background = bg_card,
        border_color = border_subtle,
        border_width = 1,
        children = children,
    })
end

local function CardHeader(icon: string, title: string, subtitle: string)
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 10,
        margin = { bottom = 4 },
        children = {
            Zenith.Text({
                text = icon,
                font_size = 14,
                color = text_accent,
            }),
            Zenith.Box({
                direction = "column",
                gap = 2,
                children = {
                    Zenith.Text({
                        text = title,
                        font_size = 13,
                        font_weight = "bold",
                        color = text_main,
                    }),
                    Zenith.Text({
                        text = subtitle,
                        font_size = 10,
                        color = text_muted,
                    }),
                }
            })
        }
    })
end

local function SettingRow(icon: string, title: string, subtitle: string, right_control: any)
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "space_between",
        width = 688,
        max_width = 688,
        padding = { y = 5 },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 12,
                flex_grow = 1,
                max_width = 400,
                children = {
                    Zenith.Box({
                        width = 20,
                        align_items = "center",
                        justify_content = "center",
                        children = {
                            Zenith.Text({
                                text = icon,
                                font_size = 13,
                                color = text_muted,
                            })
                        }
                    }),
                    Zenith.Box({
                        direction = "column",
                        gap = 2,
                        children = {
                            Zenith.Text({
                                text = title,
                                font_size = 12,
                                font_weight = "medium",
                                color = text_main,
                            }),
                            Zenith.Text({
                                text = subtitle,
                                font_size = 10,
                                color = text_muted,
                            }),
                        }
                    })
                }
            }),
            right_control,
        }
    })
end

local function SwitchControl(storage_key: string, is_checked: boolean)
    return Zenith.Switch({
        id = "switch_" .. storage_key,
        checked = is_checked,
        width = 42,
        height = 22,
        active_color = Zenith.hex(accent_hex),
        inactive_color = Zenith.rgba(255, 255, 255, 28),
        thumb_color = Zenith.hex("#ffffff"),
        on_toggle = "storage:toggle:" .. storage_key,
    })
end

local function SwitchRow(icon: string, title: string, subtitle: string, storage_key: string)
    local raw_val = Store.get(storage_key)
    local val = if raw_val == true or raw_val == 1 then true else false
    return SettingRow(icon, title, subtitle, SwitchControl(storage_key, val))
end

local function ChoiceChips(storage_key: string, options: { string }, active_val: string)
    local chips: { any } = {}
    for _, opt in ipairs(options) do
        local is_sel = (opt == active_val)
        table.insert(chips, Zenith.Box({
            padding = { x = 8, y = 4 },
            border_radius = 6,
            background = if is_sel then chip_active_bg else chip_inactive_bg,
            border_color = if is_sel then Zenith.rgba(0, 0, 0, 0) else border_subtle,
            border_width = 1,
            on_click = "storage:set:" .. storage_key .. ":" .. opt,
            children = {
                Zenith.Text({
                    text = opt,
                    font_size = 10,
                    font_weight = if is_sel then "bold" else "normal",
                    color = if is_sel then chip_active_fg else chip_inactive_fg,
                })
            }
        }))
    end
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 4,
        children = chips,
    })
end

local function ActionButton(label: string, icon: string, action_cmd: string, variant: string?)
    local is_accent = variant == "primary"
    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 6,
        padding = { x = 12, y = 6 },
        border_radius = 6,
        background = if is_accent then chip_active_bg else chip_inactive_bg,
        border_color = border_subtle,
        border_width = 1,
        on_click = action_cmd,
        children = {
            Zenith.Text({
                text = icon,
                font_size = 11,
                color = if is_accent then chip_active_fg else text_main,
            }),
            Zenith.Text({
                text = label,
                font_size = 11,
                font_weight = "medium",
                color = if is_accent then chip_active_fg else text_main,
            }),
        }
    })
end

local function SliderControl(storage_key: string, min_v: number, max_v: number, cur_v: number, unit: string?)
    local u = unit or ""
    local val = math.clamp(cur_v, min_v, max_v)
    local range = math.max(1, max_v - min_v)

    local step = if range > 50 then 2 else 1
    local v_down = math.max(min_v, math.floor(val + 0.5) - step)
    local v_up = math.min(max_v, math.floor(val + 0.5) + step)

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 8,
        children = {
            -- [-] Fine Step Down
            Zenith.Box({
                width = 24,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                on_click = "storage:set:" .. storage_key .. ":" .. tostring(v_down),
                children = {
                    Zenith.Text({
                        text = "−",
                        font_size = 14,
                        font_weight = "bold",
                        color = text_main,
                    })
                }
            }),

            -- Continuous Interactive Hardware Slider
            Zenith.Slider({
                id = "slider_" .. storage_key,
                min = min_v,
                max = max_v,
                value = val,
                width = 126,
                height = 20,
                track_height = 6,
                thumb_radius = 6,
                track_color = Zenith.rgba(255, 255, 255, 25),
                active_track_color = Zenith.hex(accent_hex),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = "storage:set:" .. storage_key,
            }),

            -- [+] Fine Step Up
            Zenith.Box({
                width = 24,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                on_click = "storage:set:" .. storage_key .. ":" .. tostring(v_up),
                children = {
                    Zenith.Text({
                        text = "+",
                        font_size = 13,
                        font_weight = "bold",
                        color = text_main,
                    })
                }
            }),

            -- Current Value Badge
            Zenith.Box({
                width = 46,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({
                        text = string.format("%d%s", math.floor(val + 0.5), u),
                        font_size = 10,
                        font_weight = "bold",
                        color = text_accent,
                    })
                }
            })
        }
    })
end

local function FloatSliderControl(storage_key: string, min_v: number, max_v: number, cur_v: number, step_v: number?, unit: string?)
    local u = unit or ""
    local step = step_v or 0.1
    local val = math.clamp(cur_v, min_v, max_v)
    local v_down = math.max(min_v, val - step)
    local v_up = math.min(max_v, val + step)

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 8,
        children = {
            Zenith.Box({
                width = 24,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                on_click = "storage:set:" .. storage_key .. ":" .. string.format("%.2f", v_down),
                children = {
                    Zenith.Text({ text = "−", font_size = 14, font_weight = "bold", color = text_main }),
                }
            }),
            Zenith.Slider({
                id = "slider_" .. storage_key,
                min = min_v,
                max = max_v,
                value = val,
                width = 126,
                height = 20,
                track_height = 6,
                thumb_radius = 6,
                track_color = Zenith.rgba(255, 255, 255, 25),
                active_track_color = Zenith.hex(accent_hex),
                thumb_color = Zenith.hex("#ffffff"),
                on_change = "storage:set:" .. storage_key,
            }),
            Zenith.Box({
                width = 24,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                on_click = "storage:set:" .. storage_key .. ":" .. string.format("%.2f", v_up),
                children = {
                    Zenith.Text({ text = "+", font_size = 13, font_weight = "bold", color = text_main }),
                }
            }),
            Zenith.Box({
                width = 46,
                height = 24,
                border_radius = 6,
                background = chip_inactive_bg,
                border_color = border_subtle,
                border_width = 1,
                align_items = "center",
                justify_content = "center",
                children = {
                    Zenith.Text({
                        text = string.format("%.1f%s", val, u),
                        font_size = 10,
                        font_weight = "bold",
                        color = text_accent,
                    }),
                }
            })
        }
    })
end

local function ColorPickerRow(icon: string, title: string, subtitle: string, storage_key: string, colors: { string }, cur_hex: string)
    local chips: { any } = {}
    for _, col in ipairs(colors) do
        local is_sel = (string.lower(col) == string.lower(cur_hex))
        table.insert(chips, Zenith.Box({
            width = 20,
            height = 20,
            border_radius = 10,
            background = Zenith.hex(col),
            border_color = if is_sel then Zenith.hex("#ffffff") else border_subtle,
            border_width = if is_sel then 2 else 1,
            on_click = "storage:set:" .. storage_key .. ":" .. col,
        }))
    end
    local right = Zenith.Box({
        direction = "row",
        align_items = "center",
        gap = 6,
        children = chips,
    })
    return SettingRow(icon, title, subtitle, right)
end

-- ── 4. Page Content Views ───────────────────────────────────────
local function RenderPageContent(page_id: number): { any }
    if page_id == 0 then
        -- ── Page 0: Quick (Exact screenshot replication) ───────────
        local cur_layout = Store.get("layoutPreset") or "Default"
        local cur_scheme = Store.get("colorScheme") or "Tonal Spot"
        local cur_accent = Store.get("accentColor") or "#fcbc00"

        local color_palette = {
            "#fcbc00", "#7aa2f7", "#bb9af7", "#b4f9f8", "#9ece6a",
            "#f7768e", "#ff9e64", "#e0af68", "#c0caf5",
        }

        local color_chips: { any } = {}
        for _, col in ipairs(color_palette) do
            local is_selected = (col == cur_accent)
            table.insert(color_chips, Zenith.Box({
                width = 16,
                height = 16,
                border_radius = 8,
                background = Zenith.hex(col),
                border_color = if is_selected then Zenith.hex("#ffffff") else Zenith.rgba(0, 0, 0, 0),
                border_width = if is_selected then 2 else 0,
                on_click = "storage:set:accentColor:" .. col,
            }))
        end

        table.insert(color_chips, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 4,
            padding = { x = 8, y = 3 },
            border_radius = 4,
            background = Zenith.rgba(255, 255, 255, 10),
            border_color = border_subtle,
            border_width = 1,
            children = {
                Zenith.Text({ text = cur_accent, font_size = 10, color = text_main }),
                Zenith.Text({ text = "✕", font_size = 9, color = text_muted, on_click = "storage:set:accentColor:#fcbc00" }),
            }
        }))

        return {
            -- Card 1: Quick Customization
            CardContainer({
                CardHeader("", "Quick Customization", "Core shell presets, active wallpaper, and overall shell dialect."),
                SettingRow("", "Wallpaper Path", "Direct path to current wallpaper image or video.", Zenith.Box({
                    width = 240,
                    padding = { x = 10, y = 6 },
                    border_radius = 6,
                    background = Zenith.rgba(0, 0, 0, 40),
                    border_color = border_subtle,
                    border_width = 1,
                    on_click = "cmd:~/.config/hypr/scripts/random-wallpaper.sh &",
                    children = {
                        Zenith.Text({ text = "/path/to/wallpaper.png", font_size = 11, color = text_muted })
                    }
                })),
                SettingRow("", "Layout Preset", "Arrangement style of the desktop shell and panels.",
                    ChoiceChips("layoutPreset", { "Default", "Compact", "Floating", "Minimal" }, cur_layout)
                ),
                SettingRow("", "Accent Color", "Quickly override the dominant accent color.",
                    Zenith.Box({ direction = "row", align_items = "center", gap = 6, children = color_chips })
                ),
                SettingRow("", "Matugen Color Scheme", "Color generation algorithm derived from wallpaper.",
                    ChoiceChips("colorScheme", { "Tonal Spot", "Vibrant", "Expressive", "Monochrome" }, cur_scheme)
                ),
            }),

            -- Card 2: Quick Shell Toggles
            CardContainer({
                CardHeader("", "Quick Shell Toggles", "Instant master overrides for behavior, animations, and privacy."),
                SwitchRow("", "Bar Auto-Hide", "Automatically hide top bar when windows are maximized or not hovered.", "barAutoHide"),
                SwitchRow("", "Compact Bar Mode", "Slim 36px bar profile with reduced padding.", "barCompactMode"),
                SwitchRow("", "Reduced Motion", "Disables spring physics and spring bounces for maximum speed.", "reducedMotion"),
                SwitchRow("", "Privacy Mode", "Anonymize sensitive media titles, notifications, and network SSIDs.", "privacyMode"),
                SwitchRow("", "Focus Mode (Do Not Disturb)", "Silences banner notifications and alerts.", "focusMode"),
                SwitchRow("", "Low Power Mode (Eco Mode)", "Optimizes blur passes, polling timers, and background sync.", "lowPowerMode"),
                SwitchRow("", "Cantos Ativos (Hot Corners)", "Trigger overview and launcher by flicking screen corners.", "enableHotCorners"),
                SwitchRow("", "Modo Zen da Barra", "Temporarily auto-hide all non-essential widgets.", "barZenMode"),
            })
        }
    elseif page_id == 1 then
        -- ── Page 1: Themes & Style (Quickshell ThemesConfig.qml) ────
        local cur_scheme = Store.get("colorScheme") or "Tonal Spot"
        local cur_dialect = Store.get("globalStyle") or "Material You"
        local cur_motion = Store.get("motionProfile") or "Snappy"
        local radius_v = Store.get("barRadius") or 18
        local blur_v = Store.get("barGlassOpacity") or 85
        local font_scale = Store.get("fontSizeScale") or 100
        local radius_scale = Store.get("radiusScale") or 100
        local spring_k = Store.get("springStiffness") or 7
        local spring_zeta = Store.get("springDamping") or 75

        return {
            CardContainer({
                CardHeader("", "Material You & Matugen M3", "Dynamic color extraction with tonal palettes and base16 tokens."),
                SettingRow("", "Algoritmo Matugen", "Selecione o estilo tonal derivado do wallpaper.",
                    ChoiceChips("colorScheme", { "Tonal Spot", "Vibrant", "Expressive", "Fruit Salad", "Monochrome" }, cur_scheme)
                ),
                SettingRow("󰈈", "Dialeto de Design", "Estética visual dominante nos cards e popups.",
                    ChoiceChips("globalStyle", { "Material You", "Aero Glass", "Cyberpunk", "Minimalist" }, cur_dialect)
                ),
                SwitchRow("", "Modo Escuro (Dark Mode)", "Alterna entre temas AMOLED escuro e tonal claro.", "darkMode"),
                SwitchRow("󰈈", "Vidro Frosted Glass", "Ativa o efeito Kawase Blur nos painéis e popups.", "glassEffect"),
            }),
            CardContainer({
                CardHeader("󱂬", "Tipografia & Geometria", "Ajuste fino de opacidade, cantos arredondados e fontes."),
                SettingRow("󰆗", "Opacidade Glassmorphism", "Nível de transparência dos fundos translúcidos.",
                    SliderControl("barGlassOpacity", 40, 100, blur_v, "%")
                ),
                SettingRow("󰄀", "Raio de Arredondamento", "Escala do border-radius dos cards e da barra.",
                    SliderControl("barRadius", 8, 28, radius_v, "px")
                ),
                SettingRow("󰤣", "Escala Global de Fonte", "Multiplicador de tamanho do texto do shell.",
                    SliderControl("fontSizeScale", 85, 130, font_scale, "%")
                ),
                SettingRow("󰄀", "Escala de Cantos (Radius)", "Multiplicador de curvatura geral de cantos.",
                    SliderControl("radiusScale", 50, 150, radius_scale, "%")
                ),
            }),
            CardContainer({
                CardHeader("", "Física de Mola (Spring Physics)", "Constantes de amortecimento e velocidade de transições."),
                SettingRow("󰑐", "Perfil de Movimento", "Personalidade das animações do shell.",
                    ChoiceChips("motionProfile", { "Snappy", "Bouncy", "Smooth", "Linear" }, cur_motion)
                ),
                SettingRow("󰓅", "Força da Mola (Stiffness k)", "Constante elástica das transições.",
                    SliderControl("springStiffness", 2, 12, spring_k, "k")
                ),
                SettingRow("󰾆", "Amortecimento (Damping Zeta)", "Dissipação de oscilação e quique.",
                    SliderControl("springDamping", 35, 95, spring_zeta, "%")
                ),
            })
        }
    elseif page_id == 2 then
        -- ── Page 2: Wallpaper (Quickshell WallpaperConfig.qml) ──────
        local cur_backend = Store.get("wallpaperBackend") or "swww"
        local cur_trans = Store.get("wallpaperTransition") or "Wipe"
        local slide_min = Store.get("wallpaperRefreshMin") or 30
        local dim_v = Store.get("overviewDim") or 40

        return {
            CardContainer({
                CardHeader("", "Motor de Papel de Parede", "Controle de plano de fundo swww, hyprpaper e animações."),
                SettingRow("", "Backend Ativo", "Motor de renderização acelerado por GPU.",
                    ChoiceChips("wallpaperBackend", { "swww", "hyprpaper", "none" }, cur_backend)
                ),
                SettingRow("", "Novo Wallpaper", "Alternar imediatamente para um wallpaper aleatório.",
                    ActionButton("Trocar Wallpaper", "󰸉", "cmd:~/.config/hypr/scripts/random-wallpaper.sh &", "primary")
                ),
                SwitchRow("", "Slideshow Automático", "Troca o plano de fundo periodicamente em segundo plano.", "wallpaperSlideshow"),
                SettingRow("󰔛", "Intervalo do Slideshow", "Tempo entre trocas automáticas de papel de parede.",
                    SliderControl("wallpaperRefreshMin", 5, 120, slide_min, "min")
                ),
                SettingRow("󰑐", "Efeito de Transição", "Tipo de animação ao alternar imagens.",
                    ChoiceChips("wallpaperTransition", { "None", "Wipe", "Wave", "Simple" }, cur_trans)
                ),
                SwitchRow("", "Pausar na Bateria", "Economiza energia pausando transições com bateria baixa.", "pauseAnimationOnBattery"),
                SwitchRow("", "Ocultar em Tela Cheia", "Pausa renderização quando jogos ou apps ocupam toda a tela.", "hideWhenFullscreen"),
                SettingRow("󰆗", "Escurecimento do Fundo (Dim)", "Nível de escurecimento do wallpaper na visão geral.",
                    SliderControl("overviewDim", 10, 80, dim_v, "%")
                ),
            })
        }
    elseif page_id == 3 then
        -- ── Page 3: Bar (Quickshell BarConfig.qml) ──────────────────
        local cur_pos = Store.get("barPosition") or "Top Edge"
        local cur_corner = Store.get("barCornerStyle") or "Floating Glass"
        local bar_h = Store.get("barHeight") or 42
        local compact_h = Store.get("barCompactHeight") or 36
        local margin_t = Store.get("barMarginTop") or 4
        local padding_i = Store.get("barPadding") or 8
        local radius_b = Store.get("barRadius") or 18
        local delay_ms = Store.get("barAutoHideDelayMs") or 200

        return {
            CardContainer({
                CardHeader("", "Geometria & Estilo da Barra", "Posicionamento, altura e curvatura dos cantos."),
                SettingRow("󰆗", "Posição na Tela", "Borda do monitor onde a barra é ancorada.",
                    ChoiceChips("barPosition", { "Top Edge", "Bottom Edge" }, cur_pos)
                ),
                SettingRow("󱂬", "Estilo dos Cantos", "Geometria da barra flutuante em relação à tela.",
                    ChoiceChips("barCornerStyle", { "Floating Glass", "Rounded Strip", "Edge-to-Edge" }, cur_corner)
                ),
                SettingRow("󰄀", "Altura da Barra Padrão", "Dimensão vertical padrão da barra flutuante.",
                    SliderControl("barHeight", 32, 56, bar_h, "px")
                ),
                SettingRow("󰄀", "Altura da Barra Compacta", "Dimensão vertical quando em modo compacto.",
                    SliderControl("barCompactHeight", 28, 44, compact_h, "px")
                ),
                SettingRow("󰄀", "Margem Superior (Gap Top)", "Distância do topo da tela até a barra flutuante.",
                    SliderControl("barMarginTop", 0, 20, margin_t, "px")
                ),
                SettingRow("󰄀", "Padding Interno dos Módulos", "Espaçamento horizontal entre ícones e pílulas.",
                    SliderControl("barPadding", 4, 16, padding_i, "px")
                ),
                SettingRow("󰄀", "Arredondamento da Barra", "Corner radius da pílula principal.",
                    SliderControl("barRadius", 8, 28, radius_b, "px")
                ),
                SwitchRow("󰆗", "Sombra Flutuante (Drop Shadow)", "Renderiza sombra suave sob a barra flutuante.", "barFloatShadow"),
            }),
            CardContainer({
                CardHeader("", "Comportamento & Ocultação Inteligente", "Regras de auto-hide e modo compacto."),
                SwitchRow("", "Ocultação Automática (Auto-Hide)", "Esconde a barra quando não estiver com o cursor sobre ela.", "barAutoHide"),
                SettingRow("󰔛", "Atraso de Revelação (Delay)", "Tempo com o mouse sobre a borda para abrir a barra.",
                    SliderControl("barAutoHideDelayMs", 50, 800, delay_ms, "ms")
                ),
                SwitchRow("", "Forçar Modo Compacto", "Ativa o perfil reduzido de 36px permanentemente.", "barCompactMode"),
            }),
            CardContainer({
                CardHeader("", "Bandeja do Sistema (Tray)", "Gerenciamento do cluster de ícones de fundo."),
                SwitchRow("", "Exibir Bandeja do Sistema", "Ativa o cluster StatusNotifierItem (SNI).", "showSystemTray"),
                SwitchRow("", "Ícones Monocromáticos", "Dessatura ícones de terceiros para estética uniforme.", "trayMonochromeIcons"),
                SwitchRow("󰈈", "Filtrar Itens Passivos", "Oculta ícones inativos até que haja notificação.", "trayFilterPassive"),
            })
        }
    elseif page_id == 4 then
        -- ── Page 4: Dock (Quickshell DockConfig.qml) ────────────────
        local cur_dock_pos = Store.get("dockPosition") or "Bottom"
        local dock_h = Store.get("dockHeight") or 52
        local icon_sz = Store.get("dockIconSize") or 40
        local hitbox_sz = Store.get("dockHitboxThickness") or 12

        return {
            CardContainer({
                CardHeader("", "Configuração do Dock Flutuante", "Barra de aplicativos fixados e atalhos rápidos."),
                SwitchRow("", "Ativar Dock Flutuante", "Exibe a dock inferior na tela principal.", "dockEnabled"),
                SettingRow("󰆗", "Posição do Dock", "Borda de ancoragem da dock de aplicativos.",
                    ChoiceChips("dockPosition", { "Bottom", "Left", "Right" }, cur_dock_pos)
                ),
                SettingRow("󰄀", "Altura do Dock", "Tamanho do contêiner da dock.",
                    SliderControl("dockHeight", 40, 72, dock_h, "px")
                ),
                SettingRow("󰄀", "Tamanho dos Ícones", "Dimensões dos ícones de apps fixados.",
                    SliderControl("dockIconSize", 24, 56, icon_sz, "px")
                ),
                SwitchRow("", "Auto-Hide Inteligente", "Dock surge suavemente ao aproximar o mouse da borda.", "dockAutoHide"),
                SettingRow("󰄀", "Espessura da Área de Revelação", "Sensibilidade da borda para acionar o dock.",
                    SliderControl("dockHitboxThickness", 4, 32, hitbox_sz, "px")
                ),
                SwitchRow("󰈈", "Vidro com Blur Kawase", "Aplica fundo translúcido fosco aos itens da dock.", "dockBlurGlass"),
                SwitchRow("", "Ícones de Apps Monocromáticos", "Aplica tema tonal aos aplicativos da dock.", "dockMonochromeIcons"),
                SwitchRow("", "Controle de Mídia na Dock", "Adiciona mini card MPRIS na extremidade da dock.", "dockShowMpris"),
                SwitchRow("", "Lixeira do Sistema", "Exibe atalho de lixeira com contagem de arquivos.", "dockShowTrash"),
                SwitchRow("󰈢", "Gaveta de Arquivos Recentes", "Acesso rápido a documentos abertos recentemente.", "dockShowRecent"),
            })
        }
    elseif page_id == 5 then
        -- ── Page 5: Panels & Popups (Quickshell PanelsConfig.qml) ───
        local cols = Store.get("overviewColumns") or 4
        local rows_n = Store.get("overviewRows") or 2
        local exp_scale = Store.get("exposeScale") or 80
        local dim_p = Store.get("overviewDim") or 40
        local cur_tl = Store.get("hotcornerTL") or "Overview"
        local cur_tr = Store.get("hotcornerTR") or "None"
        local dwell_ms = Store.get("cornerDwellTime") or 150

        return {
            CardContainer({
                CardHeader("", "Visão Geral & Grade Exposé", "Gerenciador espacial de áreas de trabalho e janelas."),
                SettingRow("󰄀", "Colunas da Grade", "Quantidade de colunas na matriz de workspaces.",
                    SliderControl("overviewColumns", 2, 6, cols, "cols")
                ),
                SettingRow("󰄀", "Linhas da Grade", "Quantidade de linhas na matriz de workspaces.",
                    SliderControl("overviewRows", 1, 4, rows_n, "rows")
                ),
                SettingRow("󰤣", "Escala das Miniaturas (Exposé)", "Tamanho relativo das janelas na visão geral.",
                    SliderControl("exposeScale", 60, 95, exp_scale, "%")
                ),
                SwitchRow("󰈈", "Backdrop Blur nos Popups", "Desfoca as janelas de fundo ao abrir popups e overview.", "popupBackdropBlur"),
                SettingRow("󰆗", "Opacidade de Escurecimento", "Nível de contraste do fundo escurecido.",
                    SliderControl("overviewDim", 10, 80, dim_p, "%")
                ),
            }),
            CardContainer({
                CardHeader("󰀸", "Cantos Ativos (Hot Corners)", "Acione menus rápidos passando o cursor pelos cantos da tela."),
                SwitchRow("", "Ativar Cantos Ativos", "Dispara ações ao aproximar o mouse dos cantos.", "enableHotCorners"),
                SettingRow("󰆗", "Canto Superior Esquerdo", "Ação ao tocar no canto superior esquerdo.",
                    ChoiceChips("hotcornerTL", { "Overview", "Dashboard", "None" }, cur_tl)
                ),
                SettingRow("󰆗", "Canto Superior Direito", "Ação ao tocar no canto superior direito.",
                    ChoiceChips("hotcornerTR", { "Launcher", "Session", "None" }, cur_tr)
                ),
                SettingRow("󰔛", "Tempo de Espera (Dwell Time)", "Tempo de permanência no canto antes de disparar.",
                    SliderControl("cornerDwellTime", 50, 500, dwell_ms, "ms")
                ),
            })
        }
    elseif page_id == 6 then
        -- ── Page 6: Dashboard (Quickshell DashboardConfig.qml) ──────
        local dash_w = Store.get("dashWidthRatio") or 70

        return {
            CardContainer({
                CardHeader("", "Dashboard Hub Central", "Tela de boas-vindas e resumo com métricas diárias."),
                SwitchRow("", "Ativar Dashboard Central", "Habilita a central de métricas e cartões.", "enableDashboard"),
                SwitchRow("󰑐", "Saudação Personalizada", "Exibe bom dia/tarde e nome do usuário no topo.", "dashGreeting"),
                SwitchRow("", "Atalhos de Energia no Topo", "Botões de desligar/reiniciar no cabeçalho.", "dashSessionButtons"),
                SettingRow("󰄀", "Proporção de Largura", "Largura do painel do dashboard em relação à tela.",
                    SliderControl("dashWidthRatio", 50, 90, dash_w, "%")
                ),
                SettingRow("", "Abrir Dashboard Agora", "Exibir a tela de visão geral completa.",
                    ActionButton("Abrir Dashboard", "", "cmd:hyprctl dispatch togglespecialworkspace dashboard &", "primary")
                ),
                SettingRow("󰒓", "Recarregar Interface", "Aplica recarga a quente nos scripts do shell.",
                    ActionButton("Hot-Reload", "󰑐", "cmd:zenith reload &")
                ),
            }),
            CardContainer({
                CardHeader("", "Módulos & Cartões do Dashboard", "Selecione os widgets exibidos na central."),
                SwitchRow("", "Previsão do Tempo", "Temperatura, umidade e previsão semanal.", "dashWeatherCard"),
                SwitchRow("", "Player de Mídia", "Capa do álbum, controle de faixa e progresso.", "dashMediaCard"),
                SwitchRow("", "Monitores de Sistema", "Gauges circulares de CPU, RAM e disco.", "dashGaugesCard"),
                SwitchRow("", "Notas Adesivas (Sticky Notes)", "Área de anotações rápidas e lembretes.", "dashNotesCard"),
            })
        }
    elseif page_id == 7 then
        -- ── Page 7: Modules (Quickshell ModulesConfig.qml) ──────────
        return {
            CardContainer({
                CardHeader("", "Cluster Esquerdo da Barra", "Módulos de inicialização, janelas e navegação."),
                SwitchRow("", "Botão do Launcher NixOS", "Exibe o ícone do sistema para abrir apps.", "showLauncherButton"),
                SwitchRow("", "Indicador de Workspaces", "Módulo de alternância das áreas de trabalho.", "showWorkspaceSwitcher"),
                SwitchRow("", "Botão de Overview", "Atalho rápido para o Mission Control / Exposé.", "showOverviewButton"),
                SwitchRow("", "Janela Ativa (Focused App)", "Mostra o título e ícone do app atualmente em foco.", "showFocusedApp"),
            }),
            CardContainer({
                CardHeader("", "Cluster Central da Barra", "Módulos de relógio, mídia, notificações e centrais."),
                SwitchRow("", "Relógio & Calendário", "Hora, data e acesso à agenda pop-up.", "showCenterClock"),
                SwitchRow("", "Controle de Mídia MPRIS", "Módulo compacto com título de faixa e play/pause.", "showCenterMedia"),
                SwitchRow("", "Sino de Notificações", "Contador de alertas e centro de notificações.", "showCenterNotifications"),
                SwitchRow("", "Status do Clima (Weather)", "Previsão do tempo e temperatura local.", "showCenterWeather"),
                SwitchRow("󰈈", "Central de Utilitários (Olho)", "Hub com atalhos de ferramentas e gravação.", "showCenterUtilityHub"),
                SwitchRow("󰒓", "Central de Configurações", "Botão que abre este menu de ajustes.", "showSettingsHub"),
                SwitchRow("󰅐", "Timer Pomodoro", "Contador de foco e pausas cronometradas.", "showPomodoro"),
            }),
            CardContainer({
                CardHeader("", "Cluster Direito da Barra", "Módulos de telemetria, conectividade e energia."),
                SwitchRow("󰄀", "Indicador de Privacidade", "Alerta de microfone, câmera e gravação ativas.", "showPrivacyIndicator"),
                SwitchRow("", "Bandeja do Sistema (Tray)", "Ícones de fundo de apps como Discord e Steam.", "showSystemTray"),
                SwitchRow("", "Monitores de Hardware", "Métricas em tempo real de CPU, RAM e temperatura.", "showHardwareMonitors"),
                SwitchRow("󰎆", "Espectro de Áudio CAVA", "Barras dançantes sincronizadas com a música.", "showCavaVisualizer"),
                SwitchRow("", "Área de Transferência", "Histórico com pesquisa de textos copiados.", "showClipboardTile"),
                SwitchRow("", "Rede & Wi-Fi", "Status de sinal, SSID e pop-up de redes sem fio.", "showNetworkStatus"),
                SwitchRow("", "Status de Áudio", "Controle rápido de volume e mixer PipeWire.", "showAudioStatus"),
                SwitchRow("", "Status de Bateria", "Nível de carga, tempo restante e perfis.", "showBatteryStatus"),
                SwitchRow("", "Layout de Teclado", "Indicador do mapa de teclas ativo (BR/US).", "showKeyboardLayout"),
                SwitchRow("", "Menu de Sessão", "Atalho para desligar, reiniciar ou bloquear a tela.", "showSessionButton"),
            })
        }
    elseif page_id == 8 then
        -- ── Page 8: System (Quickshell SystemConfig.qml - Complete!) ─
        local vol_step = Store.get("audioVolumeStep") or 5
        local cur_profile = Store.get("batteryPowerProfile") or "Balanced"
        local chg_limit = Store.get("batteryChargeLimit") or 80
        local low_bat = Store.get("batteryLowThreshold") or 20
        local crit_bat = Store.get("batteryCriticalThreshold") or 5
        local susp_min = Store.get("suspendTimeoutMin") or 15
        local night_temp = Store.get("nightLightTemp") or 4000
        local gray_val = Store.get("grayscaleIntensity") or 0
        local lock_blur = Store.get("hyprlockBlur") or 8
        local lock_grace = Store.get("hyprlockGrace") or 5
        local cur_timefmt = Store.get("timeFormat") or "24-Hour"
        local pomo_focus = Store.get("pomodoroFocus") or 25
        local pomo_break = Store.get("pomodoroBreak") or 5

        return {
            CardContainer({
                CardHeader("", "Áudio & Roteamento PipeWire", "Gerenciamento de volume, canais e proteção auditiva."),
                SettingRow("", "Passo de Ajuste de Volume", "Percentual alterado por scroll ou tecla de atalho.",
                    SliderControl("audioVolumeStep", 1, 10, vol_step, "%")
                ),
                SwitchRow("󰝟", "Trava de Segurança Auditiva", "Impede aumento acidental de volume acima de 100%.", "audioProtection"),
                SettingRow("", "Ajustes Rápidos de Volume", "Altere em passos ou acione mixer completo.",
                    Zenith.Box({
                        direction = "row",
                        gap = 6,
                        children = {
                            ActionButton("-5%", "󰕾", "audio:volume_step:-5"),
                            ActionButton("+5%", "󰕾", "audio:volume_step:5"),
                            ActionButton("Mudo", "󰝟", "audio:toggle_mute"),
                            ActionButton("Pavucontrol", "󰓃", "cmd:pavucontrol &", "primary"),
                        }
                    })
                ),
                SettingRow("", "Rede & Wi-Fi Hub", "Conectar a redes sem fio disponíveis.",
                    ActionButton("Abrir Hub Wi-Fi", "", "popup:toggle:NetworkPopup", "primary")
                ),
                SettingRow("󰂯", "Bluetooth", "Alternar alimentação do adaptador Bluetooth.",
                    ActionButton("Alternar Bluetooth", "󰂯", "bluetooth:toggle")
                ),
            }),
            CardContainer({
                CardHeader("", "Energia & Gestão de Bateria", "Perfis de consumo, limites de carga e suspensão."),
                SettingRow("", "Perfil de Energia Ativo", "Ajuste via power-profiles-daemon do Linux.",
                    ChoiceChips("batteryPowerProfile", { "Power-Saver", "Balanced", "Performance" }, cur_profile)
                ),
                SettingRow("󰂄", "Limite de Carga (Longevidade)", "Interrompe carga no limite para proteger a célula.",
                    SliderControl("batteryChargeLimit", 60, 100, chg_limit, "%")
                ),
                SettingRow("󰂃", "Alerta de Bateria Fraca", "Dispara notificação de aviso preventivo.",
                    SliderControl("batteryLowThreshold", 10, 35, low_bat, "%")
                ),
                SettingRow("󰂎", "Nível Crítico de Hibernação", "Ponto em que ação de emergência suspende o sistema.",
                    SliderControl("batteryCriticalThreshold", 3, 15, crit_bat, "%")
                ),
                SwitchRow("", "Notificar ao Atingir Carga Limite", "Emite toast sonoro e visual ao carregar totalmente.", "batteryNotifyFull"),
                SettingRow("", "Tempo de Suspensão Automática", "Minutos sem uso até suspender (0 desativa).",
                    SliderControl("suspendTimeoutMin", 0, 60, susp_min, "min")
                ),
            }),
            CardContainer({
                CardHeader("", "Luz Noturna & Conforto Visual", "Redução de luz azul e descanso ocular noturno."),
                SwitchRow("", "Ativar Luz Noturna (Night Light)", "Temperatura de cor quente para descanso visual.", "nightLightEnabled"),
                SettingRow("󰌵", "Temperatura de Cor (Kelvin)", "Valores mais baixos geram tonalidade mais quente.",
                    SliderControl("nightLightTemp", 2500, 6500, night_temp, "K")
                ),
                SettingRow("󰄀", "Filtro em Escala de Cinza", "Dessatura a tela para reduzir fadiga e estímulos.",
                    SliderControl("grayscaleIntensity", 0, 100, gray_val, "%")
                ),
            }),
            CardContainer({
                CardHeader("", "Tela de Bloqueio (Hyprlock)", "Segurança, tempo de tolerância e privacidade."),
                SettingRow("󰈈", "Desfoque de Fundo no Bloqueio", "Raio de desfoque aplicado às janelas ao bloquear.",
                    SliderControl("hyprlockBlur", 0, 16, lock_blur, "px")
                ),
                SettingRow("󰔛", "Período de Graça (Sem Senha)", "Segundos após o bloqueio onde desbloqueia sem senha.",
                    SliderControl("hyprlockGrace", 0, 30, lock_grace, "s")
                ),
                SwitchRow("", "Exibir Relógio no Bloqueio", "Renderiza relógio tipográfico na tela de bloqueio.", "hyprlockShowClock"),
            }),
            CardContainer({
                CardHeader("", "Data, Hora & Pomodoro", "Padrões de formatação e intervalos de produtividade."),
                SettingRow("", "Formato de Horário", "Selecione entre padrão 24 horas ou AM/PM.",
                    ChoiceChips("timeFormat", { "24-Hour", "12-Hour AM/PM" }, cur_timefmt)
                ),
                SwitchRow("", "Exibir Segundos no Relógio", "Mostra os segundos no módulo central da barra.", "secondPrecision"),
                SettingRow("󰅐", "Sessão de Foco Pomodoro", "Duração padrão de foco ininterrupto.",
                    SliderControl("pomodoroFocus", 15, 60, pomo_focus, "min")
                ),
                SettingRow("󰅐", "Pausa Curta Pomodoro", "Tempo de relaxamento entre ciclos de foco.",
                    SliderControl("pomodoroBreak", 3, 15, pomo_break, "min")
                ),
            })
        }
    elseif page_id == 9 then
        -- ── Page 9: Tools & Capture (Quickshell ToolsConfig.qml) ────
        local cur_fps = Store.get("toolsFps") or "60 FPS"
        local cur_codec = Store.get("toolsCodec") or "libx264"
        local cur_audio = Store.get("toolsAudioSource") or "System & Mic"
        local cur_cont = Store.get("toolsContainer") or "MKV"
        local cur_fmt = Store.get("toolsFormat") or "PNG (Lossless)"
        local cur_snip = Store.get("toolsSnipMode") or "Region Snip"
        local cur_ocr = Store.get("toolsOcrLang") or "Português"
        local cur_lens = Store.get("toolsLensProvider") or "Google Lens"
        local delay_s = Store.get("toolsDelay") or 0
        local cross_sz = Store.get("toolsCrosshairSize") or 16

        return {
            CardContainer({
                CardHeader("", "Gravação de Tela (wf-recorder)", "Taxa de quadros, compressão e codecs acelerados."),
                SettingRow("󰓅", "Taxa de Quadros (FPS)", "Taxa de captura de frames por segundo.",
                    ChoiceChips("toolsFps", { "30 FPS", "60 FPS", "120 FPS" }, cur_fps)
                ),
                SettingRow("󰕧", "Codec de Vídeo", "Algoritmo de compressão de gravação.",
                    ChoiceChips("toolsCodec", { "libx264", "libx265", "VP9" }, cur_codec)
                ),
                SettingRow("", "Fonte de Áudio", "Streams de áudio embutidos na gravação.",
                    ChoiceChips("toolsAudioSource", { "System & Mic", "System Only", "Mic Only", "Muted" }, cur_audio)
                ),
                SettingRow("󰈢", "Formato de Arquivo", "Contêiner de vídeo gerado.",
                    ChoiceChips("toolsContainer", { "MKV", "MP4" }, cur_cont)
                ),
                SwitchRow("󰙯", "Compressão Automática Discord", "Otimiza o arquivo final para o limite de 25MB.", "toolsDiscordCompress"),
                SettingRow("", "Controle de Gravação", "Iniciar ou finalizar gravação de vídeo.",
                    ActionButton("Alternar Gravação", "", "record:toggle", "primary")
                ),
            }),
            CardContainer({
                CardHeader("", "Captura de Tela & OCR", "Formatos, atraso e reconhecimento de texto."),
                SettingRow("", "Formato da Imagem", "Formato de arquivo para screenshots salvas.",
                    ChoiceChips("toolsFormat", { "PNG (Lossless)", "WebP", "JPEG" }, cur_fmt)
                ),
                SettingRow("", "Modo Padrão de Recorte", "Comportamento inicial ao pressionar tecla de print.",
                    ChoiceChips("toolsSnipMode", { "Region Snip", "Window", "Full Screen" }, cur_snip)
                ),
                SettingRow("󰔛", "Atraso na Captura (Timer)", "Segundos de contagem regressiva antes de fotografar.",
                    SliderControl("toolsDelay", 0, 10, delay_s, "s")
                ),
                SettingRow("󰤣", "Idioma de Leitura OCR", "Modelo de reconhecimento de texto do Tesseract.",
                    ChoiceChips("toolsOcrLang", { "Português", "English", "Español" }, cur_ocr)
                ),
                SettingRow("", "Busca Reversa (Lens)", "Motor de busca reversa por imagem selecionada.",
                    ChoiceChips("toolsLensProvider", { "Google Lens", "Bing Visual", "Yandex" }, cur_lens)
                ),
                SettingRow("", "Ações Imediatas de Captura", "Disparadores de print de tela e cores.",
                    Zenith.Box({
                        direction = "row",
                        gap = 6,
                        children = {
                            ActionButton("Recorte", "", "screenshot:area", "primary"),
                            ActionButton("Tela Cheia", "", "screenshot:full"),
                            ActionButton("Pipeta", "", "cmd:hyprpicker -a &"),
                        }
                    })
                ),
            }),
            CardContainer({
                CardHeader("󰄀", "Mira Central para Jogos (Reticle)", "Overlay de mira fixa para jogos sem retículo nativo."),
                SwitchRow("󰄀", "Ativar Mira Central", "Desenha retículo no ponto central exato da tela.", "toolsCrosshair"),
                SettingRow("󰄀", "Tamanho da Mira", "Diâmetro em pixels do retículo central.",
                    SliderControl("toolsCrosshairSize", 8, 48, cross_sz, "px")
                ),
            })
        }
    elseif page_id == 10 then
        -- ── Page 10: Compositor (Quickshell CompositorConfig.qml) ───
        local cur_tiling = Store.get("hyprLayout") or "Dwindle"
        local gaps_i = Store.get("gapsIn") or 5
        local gaps_o = Store.get("gapsOut") or 10
        local border_sz = Store.get("borderSize") or 2
        local cursor_sp = Store.get("cursorSpeed") or 10

        return {
            CardContainer({
                CardHeader("", "Compositor Hyprland & Tiling", "Window tiling geometry, inner/outer gaps, and border boundaries."),
                SettingRow("", "Algoritmo de Tiling", "Padrão de posicionamento automático das janelas.",
                    ChoiceChips("hyprLayout", { "Dwindle", "Master" }, cur_tiling)
                ),
                SettingRow("󰄀", "Gaps Internos (Entre Janelas)", "Espaçamento em pixels entre janelas lado a lado.",
                    SliderControl("gapsIn", 0, 24, gaps_i, "px")
                ),
                SettingRow("󰄀", "Gaps Externos (Bordas da Tela)", "Espaço entre janelas e as extremidades do monitor.",
                    SliderControl("gapsOut", 0, 40, gaps_o, "px")
                ),
                SettingRow("󰄀", "Espessura da Borda", "Largura do contorno visual das janelas.",
                    SliderControl("borderSize", 0, 6, border_sz, "px")
                ),
                SettingRow("", "Ações Rápidas de Janela", "Atalhos de tiling e balanceamento.",
                    Zenith.Box({
                        direction = "row",
                        gap = 6,
                        children = {
                            ActionButton("Ciclar Layout", "", "cmd:~/.config/hypr/scripts/cycle_layout.sh &"),
                            ActionButton("Centralizar", "󰨃", "cmd:~/.config/hypr/scripts/center_window.sh &"),
                            ActionButton("Game Mode", "󰊴", "cmd:~/.config/hypr/scripts/gamemode.sh &", "primary"),
                            ActionButton("Resetar Regras", "󰁨", "cmd:~/.config/hypr/scripts/emergency_reset.sh &"),
                        }
                    })
                ),
            }),
            CardContainer({
                CardHeader("", "Dispositivos de Entrada & Touchpad", "Sensibilidade do cursor, toques e scroll natural."),
                SettingRow("󰓅", "Sensibilidade do Cursor", "Multiplicador de aceleração do ponteiro do mouse.",
                    SliderControl("cursorSpeed", 2, 20, cursor_sp, "x0.1")
                ),
                SwitchRow("", "Scroll Natural no Touchpad", "Direção natural ao rolar páginas com dois dedos.", "touchpadNaturalScroll"),
                SwitchRow("", "Toque para Clicar (Tap-to-Click)", "Habilita clique com leve toque no touchpad.", "touchpadTapToClick"),
            })
        }
    elseif page_id == 11 then
        -- ── Page 11: Services (Quickshell ServicesConfig.qml) ───────
        local cur_wprov = Store.get("weatherProvider") or "Open-Meteo"
        local cur_wunits = Store.get("weatherUnits") or "Metric (°C, km/h)"
        local w_sync = Store.get("weatherRefreshMin") or 30
        local cur_term = Store.get("appTerminal") or "foot"
        local cur_browser = Store.get("appBrowser") or "firefox"
        local cur_fm = Store.get("appFileManager") or "thunar"
        local cur_editor = Store.get("appEditor") or "codium"
        local cur_task = Store.get("appTaskManager") or "btop"

        return {
            CardContainer({
                CardHeader("", "Serviço Meteorológico (Weather)", "Previsão do tempo e preferências de localização."),
                SettingRow("", "Provedor Meteorológico", "API de consulta meteorológica em tempo real.",
                    ChoiceChips("weatherProvider", { "Open-Meteo", "wttr.in" }, cur_wprov)
                ),
                SettingRow("󰔄", "Unidades de Medida", "Escala de temperatura e velocidade do vento.",
                    ChoiceChips("weatherUnits", { "Metric (°C, km/h)", "Imperial (°F, mph)" }, cur_wunits)
                ),
                SettingRow("󰔛", "Intervalo de Atualização", "Minutos entre consultas em segundo plano.",
                    SliderControl("weatherRefreshMin", 15, 120, w_sync, "min")
                ),
            }),
            CardContainer({
                CardHeader("", "Visualizador de Áudio & Tocadores", "Filtro de tocadores MPRIS e espectro de frequência."),
                SwitchRow("󰎆", "Espectro CAVA na Barra", "Renderiza barras de frequência animadas sob a barra.", "showCavaVisualizer"),
                SwitchRow("", "Filtrar Tocadores Duplicados", "Ignora players de abas secundárias de navegadores.", "mediaFilterDuplicates"),
            }),
            CardContainer({
                CardHeader("󰒓", "Aplicativos Padrão do Sistema", "Binários executados pelos atalhos e widgets."),
                SettingRow("", "Terminal Padrão", "Emulador de terminal preferencial.",
                    ChoiceChips("appTerminal", { "foot", "kitty", "alacritty" }, cur_term)
                ),
                SettingRow("", "Navegador Web", "Navegador de internet principal.",
                    ChoiceChips("appBrowser", { "firefox", "zen", "chromium" }, cur_browser)
                ),
                SettingRow("", "Gerenciador de Arquivos", "Explorador de pastas gráfico.",
                    ChoiceChips("appFileManager", { "thunar", "dolphin", "nautilus" }, cur_fm)
                ),
                SettingRow("", "Editor de Código", "Editor de texto ou IDE de desenvolvimento.",
                    ChoiceChips("appEditor", { "codium", "code", "nvim" }, cur_editor)
                ),
                SettingRow("", "Monitor de Tarefas", "Monitor de recursos e processos do sistema.",
                    ChoiceChips("appTaskManager", { "btop", "htop" }, cur_task)
                ),
            })
        }
    elseif page_id == 12 then
        -- ── Page 12: AI & Copilot (Quickshell AiConfig.qml) ──────────
        local cur_aiprov = Store.get("aiProvider") or "Google Gemini"
        local cur_model = Store.get("aiModel") or "gemini-2.5-flash"
        local cur_temp = Store.get("aiTemperature") or 70
        local cur_speech = Store.get("aiVoiceProvider") or "Local Whisper"
        local cur_lang = Store.get("aiVoiceLanguage") or "Auto-detect"

        return {
            CardContainer({
                CardHeader("󰚩", "Provedor de IA & Modelo", "Assistente inteligente integrado ao launcher e desktop."),
                SettingRow("", "Provedor de LLM", "Motor de IA conversacional para respostas e comandos.",
                    ChoiceChips("aiProvider", { "Google Gemini", "Groq (Llama)", "OpenAI", "Local Ollama" }, cur_aiprov)
                ),
                SettingRow("󰈈", "Modelo Selecionado", "Identificador do modelo LLM em execução.",
                    ChoiceChips("aiModel", { "gemini-2.5-flash", "llama-3.3-70b", "gpt-4o-mini", "qwen2.5:7b" }, cur_model)
                ),
                SettingRow("󰔄", "Temperatura de Amostragem", "Aleatoriedade e criatividade das respostas.",
                    SliderControl("aiTemperature", 0, 100, cur_temp, "%")
                ),
            }),
            CardContainer({
                CardHeader("", "Ditado por Voz & Transcrição", "Reconhecimento de fala via Whisper e atalhos."),
                SwitchRow("", "Busca por Ditado de Voz", "Segure atalho para ditar pesquisas no launcher.", "aiVoiceInput"),
                SettingRow("󰕧", "Motor de Transcrição", "Backend de processamento de áudio para texto.",
                    ChoiceChips("aiVoiceProvider", { "Local Whisper", "Groq Whisper API" }, cur_speech)
                ),
                SettingRow("󰤣", "Idioma Falado", "Idioma primário para transcrição de áudio.",
                    ChoiceChips("aiVoiceLanguage", { "Auto-detect", "Português", "English" }, cur_lang)
                ),
            })
        }
    elseif page_id == 13 then
        -- ── Page 13: Autostart (Quickshell AutostartConfig.qml) ──────
        return {
            CardContainer({
                CardHeader("", "Serviços & Daemons de Inicialização", "Processos em segundo plano iniciados com o Hyprland."),
                SwitchRow("", "Hypridle Daemon", "Gerenciamento de inatividade, suspensão e tela preta.", "autostartHypridle"),
                SwitchRow("", "Swww Daemon", "Motor acelerado por GPU para papéis de parede.", "autostartSwww"),
                SwitchRow("", "Playerctl Daemon", "Roteamento e priorização de tocadores MPRIS.", "autostartPlayerctl"),
                SwitchRow("", "Polkit Authentication", "Diálogo de permissões de administrador.", "autostartPolkit"),
                SwitchRow("", "Cliphist Watcher", "Histórico contínuo da área de transferência.", "autostartCliphist"),
            }),
            CardContainer({
                CardHeader("󰒓", "Gerenciamento de Serviços", "Recarregue daemons ou aplique alterações."),
                SettingRow("󰑐", "Reiniciar Serviços", "Reinicia os daemons de segundo plano.",
                    ActionButton("Reiniciar Daemons", "󰑐", "cmd:~/.config/hypr/scripts/restart_services.sh &", "primary")
                ),
                SettingRow("", "Recarregar Hyprland", "Recarrega configurações do compositor.",
                    ActionButton("Recarregar Compositor", "", "cmd:hyprctl reload &")
                ),
            })
        }
    elseif page_id == 14 then
        -- ── Page 14: Advanced (Quickshell AdvancedConfig.qml) ───────
        local low_thresh = Store.get("advancedLowPower") or 20
        local cur_log = Store.get("advancedLogLevel") or "Info"

        return {
            CardContainer({
                CardHeader("", "Desempenho & Memória", "Orçamento de memória e otimização de shaders."),
                SettingRow("", "Gatilho do Modo Eco", "Percentual de bateria que ativa economia extrema.",
                    SliderControl("advancedLowPower", 5, 40, low_thresh, "%")
                ),
                SwitchRow("󰈈", "Kawase Blur por Hardware", "Passes de desfoque acelerados na GPU.", "advancedBlur"),
                SettingRow("󰈈", "Nível de Log do Shell", "Verbosidade de saída de log no journal.",
                    ChoiceChips("advancedLogLevel", { "Info", "Warning", "Debug" }, cur_log)
                ),
                SwitchRow("", "Avisos de Memória Alta", "Notifica quando o shell ultrapassa o limite de RAM.", "advancedMemWarning"),
            }),
            CardContainer({
                CardHeader("", "Manutenção & Persistência", "Gravação no disco, restauração e diagnóstico."),
                SettingRow("", "Salvar & Persistir Agora", "Grava imediatamente todas as alterações na memória física.",
                    ActionButton("Flush Storage", "󰆓", "storage:set:flush:now", "primary")
                ),
                SettingRow("󰑐", "Restaurar Padrões de Fábrica", "Restaura todos os valores padrão do iNiR e Quickshell.",
                    ActionButton("Restaurar Padrões", "󰑐", "storage:set:reset_defaults:true")
                ),
                SettingRow("", "Diagnóstico de Saúde", "Executa a verificação dos serviços e daemons ativos.",
                    ActionButton("Diagnosticar", "", "cmd:~/.config/hypr/scripts/system_diagnose.sh &")
                ),
                SettingRow("", "Visualizar Logs do Shell", "Acompanha os logs ao vivo em um terminal.",
                    ActionButton("Abrir Logs", "", "cmd:foot -e journalctl --user -u zenith-shell -f &")
                ),
            })
        }
    elseif page_id == 15 then
        -- ── Page 15: Shortcuts Reference (Quickshell ShortcutsConfig.qml)
        local shortcut_list = {
            { key = "Super + Espaço", desc = "Abrir Launcher de Aplicativos" },
            { key = "Super + Tab", desc = "Visão Geral (Overview / Mission Control)" },
            { key = "Super + I", desc = "Abrir Menu de Configurações (.luau)" },
            { key = "Super + Shift + I", desc = "Abrir Configurações Quickshell Legadas" },
            { key = "Super + V", desc = "Histórico da Área de Transferência (Clipboard)" },
            { key = "Super + P", desc = "Menu de Sessão & Desligamento" },
            { key = "Super + Print", desc = "Captura de Tela com Recorte" },
            { key = "Super + Shift + R", desc = "Gravação de Tela (WF-Recorder)" },
            { key = "Super + Q", desc = "Fechar Janela Focada" },
            { key = "Super + Enter", desc = "Abrir Terminal Foot" },
        }

        local rows: { any } = {
            CardHeader("", "Atalhos Globais do Zenith Shell & Hyprland", "Guia rápido de teclas de atalho configuradas no sistema.")
        }
        for _, s in ipairs(shortcut_list) do
            table.insert(rows, Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                padding = { y = 4 },
                children = {
                    Zenith.Text({ text = s.desc, font_size = 11, color = text_main }),
                    Zenith.Box({
                        padding = { x = 8, y = 3 },
                        border_radius = 4,
                        background = chip_inactive_bg,
                        border_color = border_subtle,
                        border_width = 1,
                        children = {
                            Zenith.Text({ text = s.key, font_size = 10, font_weight = "bold", color = text_accent })
                        }
                    })
                }
            }))
        end

        return { CardContainer(rows) }
    else
        -- ── Page 16: About (Quickshell AboutConfig.qml) ─────────────
        return {
            CardContainer({
                CardHeader("", "Zenith Shell Engine v2.0", "Wayland Desktop Shell Framework desenvolvido em Rust + Luau."),
                SettingRow("", "Versão do Engine", "Zenith v2.0-engine (Wayland Layer-Shell + Smithay)",
                    Zenith.Text({ text = "v2.0.0-release", font_size = 11, font_weight = "bold", color = text_accent })
                ),
                SettingRow("", "Sistema Operacional", "NixOS GNU/Linux (Declarative Desktop Environment)",
                    Zenith.Text({ text = "NixOS Unstable", font_size = 11, color = text_muted })
                ),
                SettingRow("", "Compositor Wayland", "Hyprland Wayland Compositor",
                    Zenith.Text({ text = "Hyprland v0.56+", font_size = 11, color = text_muted })
                ),
                SettingRow("󰑐", "Recarregar Shell", "Aplica hot-reload sem reiniciar o sistema operacional.",
                    ActionButton("Recarregar Shell", "󰑐", "cmd:zenith reload &", "primary")
                ),
            })
        }
    end
end

-- ── 5. Sidebar Navigation Item Builder ──────────────────────────
local function BuildNavItems(): { any }
    local items: { any } = {}
    local current_cat = ""

    for _, p in ipairs(PAGES) do
        -- Category label header
        if p.category ~= current_cat then
            current_cat = p.category
            table.insert(items, Zenith.Box({
                margin = { top = 8, bottom = 2, left = 6 },
                children = {
                    Zenith.Text({
                        text = current_cat,
                        font_size = 9,
                        font_weight = "bold",
                        color = text_muted,
                    })
                }
            }))
        end

        local is_sel = (p.id == active_page)
        local item_bg = if is_sel then chip_active_bg else Zenith.rgba(0, 0, 0, 0)
        local item_title_col = if is_sel then chip_active_fg else text_main
        local item_icon_col = if is_sel then chip_active_fg else text_muted

        table.insert(items, Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            height = 24,
            padding = { x = 6, y = 2 },
            border_radius = 5,
            background = item_bg,
            on_click = "settings:page:" .. tostring(p.id),
            children = {
                Zenith.Box({
                    width = 16,
                    align_items = "center",
                    justify_content = "center",
                    children = {
                        Zenith.Text({
                            text = p.icon,
                            font_size = 11,
                            color = item_icon_col,
                        })
                    }
                }),
                Zenith.Text({
                    text = p.name,
                    font_size = 10,
                    font_weight = if is_sel then "bold" else "medium",
                    color = item_title_col,
                })
            }
        }))
    end

    return items
end

-- ── 6. Root Layout: Modal Window (1040 x 660) ────────────────────
return Zenith.Window({
    direction = "row",
    width = 1040,
    height = 660,
    anchor = { top = true },
    margins = { top = 48 },
    background = bg_surface,
    border_color = border_subtle,
    border_width = 1,
    border_radius = 16,
    shadow = {
        color = Zenith.rgba(0, 0, 0, 180),
        blur = 32,
        offset_x = 0,
        offset_y = 10,
    },
    children = {
        -- ── LEFT SIDEBAR (Width: 260) ─────────────────────────────
        Zenith.Box({
            width = 260,
            height = 660,
            direction = "column",
            background = bg_sidebar,
            border_color = border_subtle,
            border_width = 1,
            padding = { x = 12, y = 14 },
            gap = 6,
            children = {
                -- Brand Header
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 10,
                    margin = { bottom = 2 },
                    children = {
                        Zenith.Box({
                            width = 30,
                            height = 30,
                            border_radius = 15,
                            background = text_accent,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = "",
                                    font_size = 13,
                                    color = chip_active_fg,
                                })
                            }
                        }),
                        Zenith.Box({
                            direction = "column",
                            gap = 1,
                            children = {
                                Zenith.Text({
                                    text = "Zenith Settings",
                                    font_size = 13,
                                    font_weight = "bold",
                                    color = text_main,
                                }),
                                Zenith.Text({
                                    text = "Shell Engine v2.0",
                                    font_size = 9,
                                    color = text_muted,
                                }),
                            }
                        })
                    }
                }),

                -- Search Input Box
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 8,
                    height = 30,
                    padding = { x = 10, y = 3 },
                    border_radius = 6,
                    background = Zenith.rgba(0, 0, 0, 45),
                    border_color = border_subtle,
                    border_width = 1,
                    margin = { bottom = 2 },
                    children = {
                        Zenith.Text({
                            text = "",
                            font_size = 10,
                            color = text_muted,
                        }),
                        Zenith.Text({
                            text = "Search settings...",
                            font_size = 10,
                            color = text_muted,
                        }),
                    }
                }),

                -- Categorized Navigation List (All 17 items with scroll-wheel support)
                Zenith.Box({
                    direction = "column",
                    height = 490,
                    max_height = 490,
                    overflow = "scroll",
                    gap = 1,
                    on_scroll_up = "settings:page:" .. tostring(math.max(0, active_page - 1)),
                    on_scroll_down = "settings:page:" .. tostring(math.min(#PAGES - 1, active_page + 1)),
                    children = BuildNavItems(),
                }),

                -- Footer Action Buttons (Flush + Close)
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 8,
                    height = 34,
                    margin = { top = 4 },
                    children = {
                        Zenith.Box({
                            flex_grow = 1,
                            height = 32,
                            direction = "row",
                            align_items = "center",
                            justify_content = "center",
                            gap = 6,
                            border_radius = 6,
                            background = chip_inactive_bg,
                            border_color = border_subtle,
                            border_width = 1,
                            on_click = "storage:set:flush:now",
                            children = {
                                Zenith.Text({ text = "󰆓", font_size = 10, color = text_main }),
                                Zenith.Text({ text = "Flush", font_size = 10, font_weight = "medium", color = text_main }),
                            }
                        }),
                        Zenith.Box({
                            flex_grow = 1,
                            height = 32,
                            direction = "row",
                            align_items = "center",
                            justify_content = "center",
                            gap = 6,
                            border_radius = 8,
                            background = chip_active_bg,
                            on_click = "popup:close",
                            children = {
                                Zenith.Text({ text = "✕", font_size = 11, font_weight = "bold", color = chip_active_fg }),
                                Zenith.Text({ text = "Close", font_size = 11, font_weight = "bold", color = chip_active_fg }),
                            }
                        }),
                    }
                }),
            }
        }),

        -- ── RIGHT MAIN CONTENT AREA ───────────────────────────────
        Zenith.Box({
            width = 760,
            max_width = 760,
            height = 660,
            direction = "column",
            padding = { x = 20, y = 18 },
            gap = 14,
            children = {
                -- Active Page Header
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 12,
                    children = {
                        Zenith.Box({
                            width = 40,
                            height = 40,
                            border_radius = 10,
                            background = Zenith.hex(accent_hex, 40),
                            border_color = Zenith.hex(accent_hex, 80),
                            border_width = 1,
                            align_items = "center",
                            justify_content = "center",
                            children = {
                                Zenith.Text({
                                    text = active_page_def.icon,
                                    font_size = 16,
                                    color = text_accent,
                                })
                            }
                        }),
                        Zenith.Box({
                            direction = "column",
                            gap = 2,
                            children = {
                                Zenith.Text({
                                    text = active_page_def.name,
                                    font_size = 18,
                                    font_weight = "bold",
                                    color = text_main,
                                }),
                                Zenith.Text({
                                    text = active_page_def.desc,
                                    font_size = 11,
                                    color = text_muted,
                                }),
                            }
                        }),
                        Zenith.Box({ flex_grow = 1 }),
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 6,
                            padding = { x = 10, y = 6 },
                            border_radius = 8,
                            background = chip_inactive_bg,
                            border_color = border_subtle,
                            border_width = 1,
                            on_click = "popup:close",
                            children = {
                                Zenith.Text({
                                    text = "",
                                    font_size = 12,
                                    color = text_muted,
                                }),
                                Zenith.Text({
                                    text = "Fechar (Esc)",
                                    font_size = 10,
                                    font_weight = "medium",
                                    color = text_main,
                                })
                            }
                        })
                    }
                }),

                -- Subtle Horizontal Divider
                Zenith.Box({
                    height = 1,
                    width = 720,
                    background = border_subtle,
                }),

                -- Scrollable Cards Section
                Zenith.Box({
                    direction = "column",
                    width = 720,
                    max_width = 720,
                    flex_grow = 1,
                    overflow = "scroll",
                    gap = 12,
                    children = RenderPageContent(active_page),
                })
            }
        })
    }
})
