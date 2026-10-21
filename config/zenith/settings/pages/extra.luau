--!strict
-- Zenith Desktop Shell — Inir-Style Extra Settings Pages (Pages 8 to 16)
-- Handles System, Tools, Compositor, Monitors, Sound, Network, Power, Security, About

local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

local ExtraPages = {}

function ExtraPages.render(page_id: number)
    if page_id == 8 then
        -- 8: Sistema & Áudio
        local active_task = Store.get("settings_task_sys_audio", "audio")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰟢",
                    title = "Sistema & Proteção de Áudio",
                    subtitle = "Sinks PipeWire, proteção contra picos de volume e luz noturna",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "audio", name = "Áudio & Volume", icon = "󰕾" },
                        { id = "protection", name = "Proteção Auditiva", icon = "󰟢" },
                        { id = "nightlight", name = "Luz Noturna", icon = "󰤄" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Proteção Auditiva & Controle de Sinks",
                    icon = "󰕾",
                    badge = "PipeWire",
                    children = {
                        Components.SwitchRow({
                            icon = "󰟢",
                            label = "Proteção Contra Picos de Volume (Earbang Protection)",
                            subtitle = "Impede saltos abruptos de volume e limita ganho máximo do fone",
                            checked = Store.get("audioProtection", true),
                            on_toggle = "storage:toggle:audioProtection",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰕾",
                            label = "Limite Máximo Permitido (%)",
                            subtitle = "Trava de segurança de volume para proteger a audição",
                            value = Store.get("maxAllowedVolume", 100),
                            min = 60,
                            max = 130,
                            step = 5,
                            unit = "%",
                            on_change = "storage:set:maxAllowedVolume",
                        }),
                    },
                }),
                Components.CardSection({
                    title = "Luz Noturna & Temperatura de Cor",
                    icon = "󰤄",
                    children = {
                        Components.SwitchRow({
                            icon = "󰤄",
                            label = "Luz Noturna (Night Light)",
                            subtitle = "Ajusta temperatura da tela durante o entardecer",
                            checked = Store.get("nightLightEnabled", false),
                            on_toggle = "storage:toggle:nightLightEnabled",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰔎",
                            label = "Temperatura de Cor (Kelvin)",
                            subtitle = "Valores mais baixos produzem tom quente amarelado",
                            value = Store.get("nightLightTemp", 4000),
                            min = 2500,
                            max = 6500,
                            step = 250,
                            unit = "K",
                            on_change = "storage:set:nightLightTemp",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 9 then
        -- 9: Ferramentas & Captura
        local active_task = Store.get("settings_task_tools", "screenshot")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰹑",
                    title = "Ferramentas & Captura",
                    subtitle = "Grim/Slurp screenshots, wf-recorder gravação de tela, OCR e clipboard",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "screenshot", name = "Captura de Tela", icon = "󰹑" },
                        { id = "recording", name = "Gravação de Vídeo", icon = "󰑋" },
                        { id = "clipboard", name = "Clipboard Histórico", icon = "󰆏" },
                        { id = "ocr", name = "Reconhecimento OCR", icon = "󰬴" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Captura Rápida & Otimizações",
                    icon = "󰹑",
                    children = {
                        Components.SwitchRow({
                            icon = "󰭹",
                            label = "Compressão Automática para Discord",
                            subtitle = "Otimiza gravações de vídeo e prints para ficarem abaixo de 10MB",
                            checked = Store.get("toolsDiscordCompress", false),
                            on_toggle = "storage:toggle:toolsDiscordCompress",
                        }),
                        Components.Divider(),
                        Components.ActionRow({
                            icon = "󰹑",
                            label = "Captura de Área Selecionada",
                            subtitle = "Atalho: Print • Salva imagem e copia para área de transferência",
                            button_label = "Capturar",
                            button_icon = "󰹑",
                            variant = "tonal",
                            on_click = "cmd:grim -g \"$(slurp)\" - | wl-copy",
                        }),
                        Components.Divider(),
                        Components.ActionRow({
                            icon = "󰬴",
                            label = "Extrair Texto na Tela (OCR Tesseract)",
                            subtitle = "Atalho: Super+T • Converte área da tela em texto pesquisável",
                            button_label = "OCR Rápido",
                            button_icon = "󰬴",
                            variant = "tonal",
                            on_click = "cmd:sh -c '$HOME/.config/hypr/scripts/ocr.sh'",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 10 then
        -- 10: Compositor & Janelas
        local active_task = Store.get("settings_task_compositor", "gaps")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰨇",
                    title = "Compositor & Janelas (Hyprland)",
                    subtitle = "Gaps internos e externos, bordas ativas, sombras e layouts",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "gaps", name = "Gaps & Margens", icon = "󰃚" },
                        { id = "borders", name = "Bordas & Cores", icon = "󰏘" },
                        { id = "animations", name = "Animações & Curvas", icon = "󰔡" },
                        { id = "layout", name = "Dwindle / Master", icon = "󰖯" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Espaçamentos & Bordas do Hyprland",
                    icon = "󰨇",
                    badge = "IPC",
                    children = {
                        Components.SliderRow({
                            icon = "󰃚",
                            label = "Espaçamento Interno / Gaps In (px)",
                            subtitle = "Distância entre janelas adjacentes no workspace",
                            value = Store.get("gapsIn", 5),
                            min = 0,
                            max = 30,
                            step = 1,
                            unit = "px",
                            on_change = "storage:set:gapsIn",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰃚",
                            label = "Espaçamento Externo / Gaps Out (px)",
                            subtitle = "Distância das janelas até as bordas da tela e da barra",
                            value = Store.get("gapsOut", 10),
                            min = 0,
                            max = 40,
                            step = 2,
                            unit = "px",
                            on_change = "storage:set:gapsOut",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰏘",
                            label = "Espessura da Borda Ativa (px)",
                            subtitle = "Contorno da janela atualmente focada",
                            value = Store.get("borderSize", 2),
                            min = 1,
                            max = 6,
                            step = 1,
                            unit = "px",
                            on_change = "storage:set:borderSize",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 11 then
        -- 11: Telas & Monitores
        local active_task = Store.get("settings_task_monitors", "outputs")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰍹",
                    title = "Telas & Monitores",
                    subtitle = "Monitores conectados, taxas de atualização, resolução e escalas Wayland",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "outputs", name = "Monitores Ativos", icon = "󰍹" },
                        { id = "scale", name = "Escala Wayland", icon = "󰍉" },
                        { id = "profiles", name = "Perfis de Tela", icon = "󰘵" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Configuração de Monitores Wayland",
                    icon = "󰍹",
                    children = {
                        Components.ActionRow({
                            icon = "󰘵",
                            label = "Alternar Perfil de Monitores",
                            subtitle = "Atalho: Super+F8 • Cicla entre perfis (Dual, Espelho, Apenas Principal)",
                            button_label = "Ciclar Perfil",
                            button_icon = "󰘵",
                            variant = "tonal",
                            on_click = "cmd:sh -c '$HOME/.config/hypr/scripts/monitor_profile.sh --cycle'",
                        }),
                        Components.Divider(),
                        Components.SwitchRow({
                            icon = "󰍉",
                            label = "Escala Fracionária Wayland",
                            subtitle = "Renderização precisa para monitores HiDPI",
                            checked = Store.get("fractionalScaling", false),
                            on_toggle = "storage:toggle:fractionalScaling",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 12 then
        -- 12: Mídia & Sons
        local active_task = Store.get("settings_task_media", "players")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰎈",
                    title = "Mídia & Sons",
                    subtitle = "Reprodutores MPRIS, visualizador CAVA e controles de reprodução",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "players", name = "Reprodutores MPRIS", icon = "󰎈" },
                        { id = "spectrum", name = "Espectro FFT", icon = "󰛄" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Reprodutores de Áudio & playerctl",
                    icon = "󰎈",
                    children = {
                        Components.SwitchRow({
                            icon = "󰌾",
                            label = "Pausar Mídia ao Bloquear Tela",
                            subtitle = "Envia sinal pause para todos os reprodutores MPRIS no bloqueio",
                            checked = Store.get("pauseMediaOnLock", true),
                            on_toggle = "storage:toggle:pauseMediaOnLock",
                        }),
                        Components.Divider(),
                        Components.SwitchRow({
                            icon = "󰸉",
                            label = "Exibir Capa do Álbum em Alta Resolução",
                            subtitle = "Baixa e aplica desfoque na arte da faixa ativa no widget de mídia",
                            checked = Store.get("showAlbumArtHiRes", true),
                            on_toggle = "storage:toggle:showAlbumArtHiRes",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 13 then
        -- 13: Rede & Bluetooth
        local active_task = Store.get("settings_task_network", "network")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰤨",
                    title = "Rede & Bluetooth",
                    subtitle = "Status de rede Wi-Fi/Ethernet, pareamento de periféricos e Bluetooth",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "network", name = "Conexões de Rede", icon = "󰤨" },
                        { id = "bluetooth", name = "Dispositivos Bluetooth", icon = "󰂯" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Conectividade Sem Fio",
                    icon = "󰤨",
                    children = {
                        Components.ActionRow({
                            icon = "󰂯",
                            label = "Alternar Rádio Bluetooth",
                            subtitle = "Liga ou desliga o rádio bluetooth do sistema",
                            button_label = "Alternar",
                            button_icon = "󰂯",
                            variant = "tonal",
                            on_click = "bluetooth:toggle",
                        }),
                        Components.Divider(),
                        Components.ActionRow({
                            icon = "󰤨",
                            label = "Escanear Redes Wi-Fi Próximas",
                            subtitle = "Busca pontos de acesso sem fio através do NetworkManager",
                            button_label = "Escanear",
                            button_icon = "󰤨",
                            variant = "tonal",
                            on_click = "cmd:nmcli dev wifi rescan",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 14 then
        -- 14: Energia & Bateria
        local active_task = Store.get("settings_task_power", "power")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰁹",
                    title = "Energia & Limites de Carga",
                    subtitle = "Perfis de consumo power-profiles-daemon, preservação de bateria e suspensão",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "power", name = "Perfis de Energia", icon = "󰁹" },
                        { id = "battery", name = "Avisos de Bateria", icon = "󰂃" },
                        { id = "suspend", name = "Suspensão Automática", icon = "󰤄" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Preservação da Saúde da Bateria",
                    icon = "󰁹",
                    children = {
                        Components.SwitchRow({
                            icon = "󰁹",
                            label = "Preservação da Saúde da Bateria",
                            subtitle = "Limita o carregamento a 80% quando conectado na tomada",
                            checked = Store.get("batteryLimitActive", true),
                            on_toggle = "storage:toggle:batteryLimitActive",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰂃",
                            label = "Limite de Carga Máxima (%)",
                            subtitle = "Cessa alimentação ao atingir a porcentagem estipulada",
                            value = Store.get("batteryChargeLimit", 80),
                            min = 60,
                            max = 100,
                            step = 5,
                            unit = "%",
                            on_change = "storage:set:batteryChargeLimit",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 15 then
        -- 15: Bloqueio de Tela
        local active_task = Store.get("settings_task_security", "hyprlock")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰌾",
                    title = "Bloqueio & Segurança (Hyprlock)",
                    subtitle = "Hyprlock, hypridle, tempo de ociosidade e autenticação PAM",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "hyprlock", name = "Tela de Bloqueio", icon = "󰌾" },
                        { id = "idle", name = "Tempo Limite / Idle", icon = "󰤄" },
                        { id = "security", name = "Polkit & Autenticação", icon = "󰘵" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Tela de Bloqueio Hyprlock",
                    icon = "󰌾",
                    children = {
                        Components.SwitchRow({
                            icon = "󰥔",
                            label = "Exibir Relógio no Bloqueio",
                            subtitle = "Renderiza data e hora centralizadas no hyprlock",
                            checked = Store.get("hyprlockShowClock", true),
                            on_toggle = "storage:toggle:hyprlockShowClock",
                        }),
                        Components.Divider(),
                        Components.SliderRow({
                            icon = "󰤄",
                            label = "Desfoque de Fundo / Blur Sigma",
                            subtitle = "Nível de desfoque aplicado sobre o desktop bloqueado",
                            value = Store.get("hyprlockBlur", 8),
                            min = 0,
                            max = 16,
                            step = 1,
                            unit = "",
                            on_change = "storage:set:hyprlockBlur",
                        }),
                        Components.Divider(),
                        Components.ActionRow({
                            icon = "󰌾",
                            label = "Bloquear Sessão Imediatamente",
                            subtitle = "Atalho: Super+L • Ativa o hyprlock",
                            button_label = "Bloquear",
                            button_icon = "󰌾",
                            variant = "tonal",
                            on_click = "lock",
                        }),
                    },
                }),
            },
        })
    elseif page_id == 16 then
        -- 16: Sobre o Zenith Shell
        local active_task = Store.get("settings_task_about", "about")
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰌽",
                    title = "Sobre o Zenith Desktop Shell",
                    subtitle = "Motor gráfico nativo Wayland em Rust + Luau JIT com design system Inir/Matugen",
                }),
                Components.TaskNavigator({
                    tasks = {
                        { id = "about", name = "Zenith Shell v0.2", icon = "󰌽" },
                        { id = "cheatsheet", name = "Atalhos de Teclado", icon = "󰌌" },
                        { id = "diagnostics", name = "Diagnóstico", icon = "󰘵" },
                    },
                    active_task = active_task,
                }),
                Components.CardSection({
                    title = "Arquitetura & Especificações Técnicas",
                    icon = "󰌽",
                    badge = "Engine v0.2.0",
                    children = {
                        Components.ActionRow({
                            icon = "󰌽",
                            label = "Zenith Shell Engine (Pure Rust + Luau JIT)",
                            subtitle = "Single-process, zero intermediate fork overhead, latência < 1ms",
                            button_label = "GitHub",
                            button_icon = "󰈔",
                            variant = "tonal",
                            on_click = "cmd:xdg-open https://github.com",
                        }),
                        Components.Divider(),
                        Components.ActionRow({
                            icon = "󰘵",
                            label = "Desenvolvido por Lucas Damasceno",
                            subtitle = "Ambiente Wayland customizado sob medida para Hyprland no NixOS",
                            button_label = "Atalhos (Super+S)",
                            button_icon = "󰌌",
                            variant = "outlined",
                            on_click = "settings:page:0",
                        }),
                    },
                }),
            },
        })
    else
        -- Fallback
        return Zenith.Box({
            direction = "column",
            width = "100%",
            gap = 12,
            children = {
                Components.PageBanner({
                    icon = "󰒓",
                    title = "Configuração do Módulo",
                    subtitle = "Módulo ativo e monitorado pelo daemon do Zenith",
                }),
                Components.CardSection({
                    title = "Estado do Módulo",
                    icon = "󰒓",
                    children = {
                        Zenith.Text({
                            text = "As configurações realizadas são sincronizadas atomicamente em ~/.config/zenith/config.json.",
                            font_family = "Inter",
                            font_size = 12,
                            color = Components.get_palette().colSubtext,
                        }),
                    },
                }),
            },
        })
    end
end

return ExtraPages
