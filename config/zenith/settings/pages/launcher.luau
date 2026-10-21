--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: App Launcher
-- Configures app launcher search, fuzzy matching, categories and backdrop blur

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function LauncherPage()
    local active_task = Store.get("settings_task_launcher", "search")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰍉",
                title = "Launcher & Pesquisa de Aplicativos",
                subtitle = "Menu de aplicativos, pesquisa fuzzy, categorias XDG, escurecimento de fundo e comandos",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "search", name = "Pesquisa & Fuzzy", icon = "󰍉" },
                    { id = "grid", name = "Grade de Apps", icon = "󰮄" },
                    { id = "actions", name = "Comandos Rápidos", icon = "󰘵" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Comportamento & Efeitos do Launcher",
                icon = "󰍉",
                badge = "Super+Space",
                children = {
                    Components.SwitchRow({
                        icon = "󰤄",
                        label = "Desfoque de Fundo nos Popups (Backdrop Blur)",
                        subtitle = "Aplica efeito de blur no papel de parede durante a pesquisa de programas",
                        checked = Store.get("popupBackdropBlur", true),
                        on_toggle = "storage:toggle:popupBackdropBlur",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰔡",
                        label = "Animações Suaves com Molas Físicas (RK4)",
                        subtitle = "Transições acionadas com amortecimento inercial sem latência",
                        checked = Store.get("popupAnimationsEnabled", true),
                        on_toggle = "storage:toggle:popupAnimationsEnabled",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰔎",
                        label = "Escurecimento do Fundo / Scrim Dimmer (%)",
                        subtitle = "Nível de escurecimento aplicado sobre as janelas ao abrir o launcher",
                        value = Store.get("overviewDim", 40),
                        min = 0,
                        max = 85,
                        step = 5,
                        unit = "%",
                        on_change = "storage:set:overviewDim",
                    }),
                },
            }),
        },
    })
end

return LauncherPage
