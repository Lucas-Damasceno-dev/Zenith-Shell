--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: Floating Dock
-- Configures dock style, physical magnification, autohide policies and indicators

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function DockPage()
    local active_task = Store.get("settings_task_dock", "style")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰀻",
                title = "Dock Flutuante",
                subtitle = "Dock estilo macOS / iPadOS, magnificação física com molas, auto-ocultação e apps fixados",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "style", name = "Estilo & Posição", icon = "󰀻" },
                    { id = "magnify", name = "Magnificação", icon = "󰍉" },
                    { id = "behavior", name = "Auto-ocultar", icon = "󰔡" },
                    { id = "apps", name = "Apps Fixados", icon = "󰤱" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Visibilidade & Comportamento do Dock",
                icon = "󰀻",
                badge = "Interativo",
                children = {
                    Components.SwitchRow({
                        icon = "󰀻",
                        label = "Habilitar Dock Flutuante",
                        subtitle = "Exibe o dock de aplicativos na parte inferior da tela",
                        checked = Store.get("dockEnabled", true),
                        on_toggle = "storage:toggle:dockEnabled",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰘓",
                        label = "Auto-ocultar com Janelas Sobrepostas",
                        subtitle = "Recolhe o dock quando uma janela maximizada ou foco cobre o rodapé",
                        checked = Store.get("dockAutoHide", true),
                        on_toggle = "storage:toggle:dockAutoHide",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰍉",
                        label = "Magnificação Contínua (Zoom Físico)",
                        subtitle = "Expande suavemente os ícones com curva gaussiana conforme o cursor aproxima",
                        checked = Store.get("dockMagnification", true),
                        on_toggle = "storage:toggle:dockMagnification",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰎈",
                        label = "Controle de Mídia Integrado",
                        subtitle = "Cápsula com controles rápidos do reprodutor MPRIS ativo",
                        checked = Store.get("dockShowMpris", true),
                        on_toggle = "storage:toggle:dockShowMpris",
                    }),
                },
            }),

            Components.CardSection({
                title = "Dimensões & Escala de Ícones",
                icon = "󰃚",
                children = {
                    Components.SliderRow({
                        icon = "󰃚",
                        label = "Altura do Dock (px)",
                        subtitle = "Espessura da superfície principal do dock",
                        value = Store.get("dockHeight", 52),
                        min = 40,
                        max = 80,
                        step = 2,
                        unit = "px",
                        on_change = "storage:set:dockHeight",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰮄",
                        label = "Tamanho Base dos Ícones (px)",
                        subtitle = "Dimensões dos lançadores no estado de repouso",
                        value = Store.get("dockIconSize", 40),
                        min = 28,
                        max = 64,
                        step = 4,
                        unit = "px",
                        on_change = "storage:set:dockIconSize",
                    }),
                },
            }),
        },
    })
end

return DockPage
