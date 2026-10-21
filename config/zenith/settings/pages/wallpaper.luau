--!strict
-- Zenith Desktop Shell — Inir-Style Settings Page: Wallpaper Engine
-- Configures wallpaper backends, slideshow, auto-extraction and background blur

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local function WallpaperPage()
    local active_task = Store.get("settings_task_wallpaper", "picker")

    return Zenith.Box({
        direction = "column",
        width = "100%",
        gap = 12,
        children = {
            Components.PageBanner({
                icon = "󰸉",
                title = "Papel de Parede & Motor de Fundo",
                subtitle = "Gerenciamento de swww/hyprpaper, troca automática e extração de cores Matugen",
            }),

            Components.TaskNavigator({
                tasks = {
                    { id = "picker", name = "Seleção", icon = "󰸉" },
                    { id = "effects", name = "Efeitos & Blur", icon = "󰛄" },
                    { id = "slideshow", name = "Slideshow", icon = "󰑖" },
                    { id = "backend", name = "Motor Gráfico", icon = "󰟢" },
                },
                active_task = active_task,
            }),

            Components.CardSection({
                title = "Ações & Seleção Rápida",
                icon = "󰸉",
                children = {
                    Components.ActionRow({
                        icon = "󰸉",
                        label = "Escolher Imagem de Papel de Parede",
                        subtitle = "Abre seletor gráfico e atualiza swww instantaneamente",
                        button_label = "Selecionar",
                        button_icon = "󰸉",
                        variant = "tonal",
                        on_click = "cmd:zenith wallpaper pick",
                    }),
                    Components.Divider(),
                    Components.ActionRow({
                        icon = "󰏘",
                        label = "Re-extrair Paleta de Cores Matugen",
                        subtitle = "Gera novos tokens de cor dinâmicos com base no papel de parede ativo",
                        button_label = "Extrair Cores",
                        button_icon = "󰏘",
                        variant = "tonal",
                        on_click = "cmd:zenith theme generate",
                    }),
                },
            }),

            Components.CardSection({
                title = "Apresentação & Comportamento Energético",
                icon = "󰑖",
                children = {
                    Components.SwitchRow({
                        icon = "󰑖",
                        label = "Apresentação de Slides Automática",
                        subtitle = "Alterna ciclicamente os papéis de parede da pasta selecionada",
                        checked = Store.get("wallpaperSlideshow", false),
                        on_toggle = "storage:toggle:wallpaperSlideshow",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰁹",
                        label = "Pausar Animações na Bateria",
                        subtitle = "Interrompe shaders e transições contínuas quando desconectado da tomada",
                        checked = Store.get("pauseAnimationOnBattery", true),
                        on_toggle = "storage:toggle:pauseAnimationOnBattery",
                    }),
                    Components.Divider(),
                    Components.SwitchRow({
                        icon = "󰖲",
                        label = "Ocultar com Janelas em Tela Cheia",
                        subtitle = "Desliga renderização do plano de fundo durante jogos ou vídeos em tela cheia",
                        checked = Store.get("hideWhenFullscreen", true),
                        on_toggle = "storage:toggle:hideWhenFullscreen",
                    }),
                    Components.Divider(),
                    Components.SliderRow({
                        icon = "󰥔",
                        label = "Intervalo de Troca (minutos)",
                        subtitle = "Tempo entre transições de imagem no slideshow",
                        value = Store.get("wallpaperRefreshMin", 30),
                        min = 5,
                        max = 120,
                        step = 5,
                        unit = "m",
                        on_change = "storage:set:wallpaperRefreshMin",
                    }),
                },
            }),
        },
    })
end

return WallpaperPage
