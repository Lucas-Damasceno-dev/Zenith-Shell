--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: Widgets & Modules
-- Granular toggle and configuration of system bar and desktop widgets

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function WidgetsPage()
    local active_task = Store.get("settings_task_widgets", "desktop")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰮄",
                title = "Widgets & Módulos da Shell",
                subtitle = "Ative ou desative individualmente os elementos da barra superior, relógio, mídia e Cava",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "desktop", name = "Widgets de Mesa", icon = "󰮄" },
                    { id = "cava", name = "Visualizador CAVA", icon = "󰎈" },
                    { id = "weather", name = "Clima & Previsão", icon = "󰖐" },
                    { id = "clock", name = "Relógio & Data", icon = "󰥔" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Módulos da Barra Superior",
                icon = "󰖯",
                badge = "Visibilidade",
                children = {
                    Components.SwitchRow({
                        icon = "󰍉",
                        label = "Botão do Menu Launcher",
                        subtitle = "Ícone de abertura rápida da gaveta de aplicativos",
                        checked = Store.get("showLauncherButton", true),
                        on_toggle = "storage:toggle:showLauncherButton",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰨇",
                        label = "Alternador de Workspaces",
                        subtitle = "Indicador numérico e visual de áreas de trabalho ativas",
                        checked = Store.get("showWorkspaceSwitcher", true),
                        on_toggle = "storage:toggle:showWorkspaceSwitcher",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰖲",
                        label = "Janela em Foco (Active Window)",
                        subtitle = "Título e ícone da aplicação ativa no momento",
                        checked = Store.get("showFocusedApp", true),
                        on_toggle = "storage:toggle:showFocusedApp",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰥔",
                        label = "Relógio Central & Calendário",
                        subtitle = "Hora em destaque e acesso rápido ao calendário",
                        checked = Store.get("showCenterClock", true),
                        on_toggle = "storage:toggle:showCenterClock",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰎈",
                        label = "Controle de Mídia MPRIS",
                        subtitle = "Faixa em reprodução via Spotify, Firefox ou playerctl",
                        checked = Store.get("showCenterMedia", true),
                        on_toggle = "storage:toggle:showCenterMedia",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰖐",
                        label = "Previsão do Tempo em Tempo Real",
                        subtitle = "Condição climática e temperatura da localização",
                        checked = Store.get("showCenterWeather", true),
                        on_toggle = "storage:toggle:showCenterWeather",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰒓",
                        label = "Bandeja do Sistema (StatusNotifierItem Tray)",
                        subtitle = "Ícones de programas rodando em segundo plano",
                        checked = Store.get("showSystemTray", true),
                        on_toggle = "storage:toggle:showSystemTray",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰍛",
                        label = "Monitores de Hardware (CPU/RAM)",
                        subtitle = "Uso de processador, memória RAM e temperatura de silício",
                        checked = Store.get("showHardwareMonitors", true),
                        on_toggle = "storage:toggle:showHardwareMonitors",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰎈",
                        label = "Visualizador de Áudio CAVA",
                        subtitle = "Barras de espectro de áudio animadas em tempo real na barra",
                        checked = Store.get("showCavaVisualizer", true),
                        on_toggle = "storage:toggle:showCavaVisualizer",
                    }),
                },
            }),
        },
    })
end

return WidgetsPage
