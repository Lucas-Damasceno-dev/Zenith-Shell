--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: Appearance & Themes
-- Personalizes Matugen M3 colors, glassmorphism, surface blur, typography and geometry

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function AppearancePage()
    local active_task = Store.get("settings_task_appearance", "themes")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            -- Page Banner
            Components.PageBanner({
                icon = "󰏘",
                title = "Aparência & Identidade Visual",
                subtitle = "Motor de cores Matugen M3, desfoque de vidro (Glassmorphism), tipografia e geometria",
            }),

            -- Task Navigator Sub-sections
            Components.TaskNavigator({
                tasks = {
                    { id = "themes", name = "Temas & Paleta", icon = "󰏘" },
                    { id = "glass", name = "Efeito de Vidro", icon = "󰤄" },
                    { id = "typography", name = "Tipografia", icon = "󰬴" },
                    { id = "radius", name = "Geometria", icon = "󰃚" },
                },
                active_task = active_task,
            }),

            -- Card 1: Efeitos Visuais & Superfícies
            Components.CardSection({
                title = "Superfícies & Transparência Wayland",
                icon = "󰤄",
                badge = "GPU",
                children = {
                    Components.SwitchRow({
                        icon = "󰤄",
                        label = "Efeito de Vidro Fosco (Glassmorphism)",
                        subtitle = "Aplica desfoque gaussiano e translucidez por hardware nas superfícies",
                        checked = Store.get("glassEffect", true),
                        on_toggle = "storage:toggle:glassEffect",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰔎",
                        label = "Opacidade das Superfícies (%)",
                        subtitle = "Nível de transparência das barras, menus e popups",
                        value = Store.get("barGlassOpacity", 85),
                        min = 30,
                        max = 100,
                        step = 5,
                        unit = "%",
                        on_change = "storage:set:barGlassOpacity",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰛄",
                        label = "Desfoque de Superfície / Blur Sigma (px)",
                        subtitle = "Intensidade do desfoque de fundo atrás de janelas e barras",
                        value = Store.get("blurRadius", 20),
                        min = 0,
                        max = 50,
                        step = 2,
                        unit = "px",
                        on_change = "storage:set:blurRadius",
                    }),
                },
            }),

            -- Card 2: Tipografia & Geometria
            Components.CardSection({
                title = "Fontes, Escala & Arredondamento",
                icon = "󰬴",
                children = {
                    Components.SliderRow({
                        icon = "󰬴",
                        label = "Escala de Tamanho das Fontes (%)",
                        subtitle = "Ajusta a proporção do texto em toda a shell",
                        value = Store.get("fontSizeScale", 100),
                        min = 80,
                        max = 140,
                        step = 5,
                        unit = "%",
                        on_change = "storage:set:fontSizeScale",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰃚",
                        label = "Arredondamento dos Cantos (%)",
                        subtitle = "Multiplicador de raio para bordas de botões, cards e janelas",
                        value = Store.get("radiusScale", 100),
                        min = 50,
                        max = 160,
                        step = 10,
                        unit = "%",
                        on_change = "storage:set:radiusScale",
                    }),
                    Components.Divider(),
                    Components.SegmentedRow({
                        icon = "󰏘",
                        label = "Preset de Paleta Visual",
                        subtitle = "Esquema de cores dominante do ambiente",
                        selected = Store.get("themePreset", "matugen"),
                        options = {
                            { id = "matugen", label = "Matugen M3" },
                            { id = "catppuccin", label = "Catppuccin" },
                            { id = "tokyonight", label = "Tokyo Night" },
                            { id = "nord", label = "Nord" },
                        },
                        on_change_action_prefix = "storage:set:themePreset",
                    }),
                },
            }),
        },
    })
end

return AppearancePage
