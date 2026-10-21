--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: Status Bar
-- Configures status bar layout, floating geometry, auto-hide and tray modules

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function BarPage()
    local active_task = Store.get("settings_task_bar", "layout")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰖯",
                title = "Barra Superior do Sistema",
                subtitle = "Posicionamento, geometria flutuante, auto-ocultação, módulos e bandeja de status",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "layout", name = "Posição & Altura", icon = "󰖯" },
                    { id = "modules", name = "Módulos & Ordem", icon = "󰮄" },
                    { id = "tray", name = "Bandeja (Tray)", icon = "󰒓" },
                    { id = "autohide", name = "Auto-ocultação", icon = "󰘓" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Geometria & Posicionamento da Barra",
                icon = "󰖯",
                badge = "Camada Top",
                children = {
                    Components.SegmentedRow({
                        icon = "󰖯",
                        label = "Posição da Barra na Tela",
                        subtitle = "Borda de fixação da superfície da barra no compositor",
                        selected = if string.lower(tostring(Store.get("barPosition", "top"))):find("bottom") then "bottom" else "top",
                        options = {
                            { id = "top", label = "Borda Superior" },
                            { id = "bottom", label = "Borda Inferior" },
                        },
                        on_change_action_prefix = "storage:set:barPosition",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰃚",
                        label = "Altura da Barra (px)",
                        subtitle = "Dimensão vertical da barra principal",
                        value = Store.get("barHeight", 42),
                        min = 28,
                        max = 60,
                        step = 2,
                        unit = "px",
                        on_change = "storage:set:barHeight",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰃚",
                        label = "Arredondamento dos Cantos (px)",
                        subtitle = "Raio de curvatura das extremidades da barra",
                        value = Store.get("barRadius", 18),
                        min = 0,
                        max = 28,
                        step = 2,
                        unit = "px",
                        on_change = "storage:set:barRadius",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰘵",
                        label = "Espaçamento Lateral / Padding (px)",
                        subtitle = "Margens internas para os módulos e botões",
                        value = Store.get("barPadding", 8),
                        min = 4,
                        max = 20,
                        step = 2,
                        unit = "px",
                        on_change = "storage:set:barPadding",
                    }),
                },
            }),

            Components.CardSection({
                title = "Comportamento & Auto-ocultação Inteligente",
                icon = "󰔡",
                children = {
                    Components.SwitchRow({
                        icon = "󰘓",
                        label = "Auto-ocultar Barra Superior",
                        subtitle = "Recolhe a barra automaticamente quando janelas tocam a borda da tela",
                        checked = Store.get("barAutoHide", true),
                        on_toggle = "storage:toggle:barAutoHide",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰮄",
                        label = "Modo Compacto",
                        subtitle = "Agrupa os indicadores de status em uma cápsula consolidada",
                        checked = Store.get("barCompactMode", false),
                        on_toggle = "storage:toggle:barCompactMode",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰤄",
                        label = "Modo Zen / Foco Total",
                        subtitle = "Exibe apenas o relógio e minimiza todas as distrações da tela",
                        checked = Store.get("barZenMode", false),
                        on_toggle = "storage:toggle:barZenMode",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰛄",
                        label = "Sombra de Elevação Flutuante",
                        subtitle = "Projeta sombra difusa suave sobre o papel de parede",
                        checked = Store.get("barFloatShadow", true),
                        on_toggle = "storage:toggle:barFloatShadow",
                    }),
                },
            }),
        },
    })
end

return BarPage
