--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: General & Essentials
-- Configures core shell behavior, theme modes, focus rules and atomic state sync

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function GeneralPage()
    local active_task = Store.get("settings_task_general", "overview")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            -- Page Banner
            Components.PageBanner({
                icon = "󰒓",
                title = "Geral & Preferências",
                subtitle = "Comportamentos essenciais, tema escuro, modo foco e sincronização de estado",
            }),

            -- Task Navigator Sub-sections
            Components.TaskNavigator({
                tasks = {
                    { id = "overview", name = "Visão Geral", icon = "󰒓" },
                    { id = "preferences", name = "Preferências", icon = "󰘵" },
                    { id = "behavior", name = "Comportamento", icon = "󰔡" },
                    { id = "sync", name = "Sincronização", icon = "󰦗" },
                },
                active_task = active_task,
            }),

            -- Grouped Card Section 1: Preferências do Sistema
            Components.CardSection({
                title = "Preferências do Sistema & Interface",
                icon = "󰘵",
                badge = "Ativo",
                children = {
                    Components.SwitchRow({
                        icon = "󰔎",
                        label = "Tema Escuro (Dark Mode)",
                        subtitle = "Alterna entre esquemas M3 escuro e claro em todas as superfícies",
                        checked = Store.get("darkMode", true),
                        on_toggle = "storage:toggle:darkMode",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰔡",
                        label = "Movimento Reduzido (Reduced Motion)",
                        subtitle = "Desativa transições com física de mola e reduz carga na GPU",
                        checked = Store.get("reducedMotion", false),
                        on_toggle = "storage:toggle:reducedMotion",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰂛",
                        label = "Modo Foco / Não Perturbe",
                        subtitle = "Silencia notificações de aplicativos não prioritários e sons de alerta",
                        checked = Store.get("focusMode", false),
                        on_toggle = "storage:toggle:focusMode",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰁹",
                        label = "Modo de Baixo Consumo (Power Saver)",
                        subtitle = "Reduz taxa de pooling de hardware e desativa shaders de fundo na bateria",
                        checked = Store.get("lowPowerMode", false),
                        on_toggle = "storage:toggle:lowPowerMode",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰃚",
                        label = "Cantos Ativos (Hot Corners)",
                        subtitle = "Aciona visão geral ao encostar o cursor nos cantos superiores da tela",
                        checked = Store.get("enableHotCorners", true),
                        on_toggle = "storage:toggle:enableHotCorners",
                    }),
                },
            }),

            -- Grouped Card Section 2: Estado & Arquivos de Configuração
            Components.CardSection({
                title = "Ações Rápidas & Sincronização",
                icon = "󰦗",
                children = {
                    Components.ActionRow({
                        icon = "󰦗",
                        label = "Sincronizar Arquivo de Configuração",
                        subtitle = "Grava todas as variáveis de runtime em ~/.config/zenith/config.json",
                        button_label = "Sincronizar",
                        button_icon = "󰦗",
                        variant = "tonal",
                        on_click = "settings:sync",
                    }),
                    Components.Divider(),
                    Components.ActionRow({
                        icon = "󰑖",
                        label = "Recarregar Shell a Quente",
                        subtitle = "Recompila scripts Luau e atualiza pipelines Wayland em sub-milissegundos",
                        button_label = "Recarregar",
                        button_icon = "󰑖",
                        variant = "tonal",
                        on_click = "reload",
                    }),
                    Components.Divider(),
                    Components.ActionRow({
                        icon = "󰁯",
                        label = "Restaurar Padrões de Fábrica",
                        subtitle = "Restaura todos os valores padrão e recarrega os módulos essenciais",
                        button_label = "Restaurar",
                        button_icon = "󰁯",
                        variant = "outlined",
                        on_click = "settings:reset_defaults",
                    }),
                },
            }),
        },
    })
end

return GeneralPage
