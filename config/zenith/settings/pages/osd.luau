--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: OSD & Notifications
-- Configures on-screen displays, toast notifications, DND mode and battery alert thresholds

local Store = Zenith.import("core/store")
local Services = Zenith.import("core/services/init")
local Components = Zenith.import("settings/components")

local function OsdPage()
    local active_task = Store.get("settings_task_osd", "osd")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰕾",
                title = "OSD & Central de Notificações",
                subtitle = "Indicadores na tela para volume e brilho, central de avisos, Não Perturbe e limites",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "osd", name = "Indicadores OSD", icon = "󰕾" },
                    { id = "notifications", name = "Notificações", icon = "󰂚" },
                    { id = "dnd", name = "Não Perturbe", icon = "󰂛" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Políticas de Notificação & Não Perturbe",
                icon = "󰂚",
                children = {
                    Components.SwitchRow({
                        icon = "󰂛",
                        label = "Modo Não Perturbe (DND)",
                        subtitle = "Silencia popups de notificação e banners visuais durante foco",
                        checked = if Services and Services.Notifications then Services.Notifications.is_dnd() else Store.get("dndEnabled", false),
                        on_toggle = "notification:toggle_dnd",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰁹",
                        label = "Notificar Carga Completa (100%)",
                        subtitle = "Emite alerta discreto quando a bateria atinge 100% para preservar saúde",
                        checked = Store.get("batteryNotifyFull", true),
                        on_toggle = "storage:toggle:batteryNotifyFull",
                    }),
                },
            }),

            Components.CardSection({
                title = "Comportamento OSD & Passos de Volume",
                icon = "󰕾",
                children = {
                    Components.SliderRow({
                        icon = "󰕾",
                        label = "Incremento de Volume por Tecla (%)",
                        subtitle = "Percentual alterado a cada toque nas teclas XF86AudioRaiseVolume/LowerVolume",
                        value = Store.get("audioVolumeStep", 5),
                        min = 1,
                        max = 15,
                        step = 1,
                        unit = "%",
                        on_change = "storage:set:audioVolumeStep",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰂃",
                        label = "Alerta de Bateria Baixa (%)",
                        subtitle = "Percentual de carga restante para disparar aviso de conexão à tomada",
                        value = Store.get("batteryLowThreshold", 20),
                        min = 10,
                        max = 35,
                        step = 5,
                        unit = "%",
                        on_change = "storage:set:batteryLowThreshold",
                    }),
                },
            }),
        },
    })
end

return OsdPage
