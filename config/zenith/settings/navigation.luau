--!strict
-- Zenith Desktop Shell — Inir-Style Sidebar Navigation & Search Registry
-- Renders categorized pages with active accent indicators, task metadata and bottom action dock

local Theme = Zenith.import("core/theme")
local Store = Zenith.import("core/store")
local Components = Zenith.import("settings/components")

export type TaskOption = {
    id: string,
    name: string,
    icon: string?,
}

export type NavigationItem = {
    id: number,
    name: string,
    icon: string,
    category: string,
    desc: string,
    essential: boolean,
    tasks: { TaskOption },
}

local PAGES: { NavigationItem } = {
    -- ESSENCIAIS
    {
        id = 0,
        name = "Geral",
        icon = "󰒓",
        category = "ESSENCIAIS",
        desc = "Preferências essenciais, tema escuro, modo foco e atalhos rápidos",
        essential = true,
        tasks = {
            { id = "overview", name = "Visão Geral", icon = "󰒓" },
            { id = "preferences", name = "Preferências", icon = "󰘵" },
            { id = "behavior", name = "Comportamento", icon = "󰔡" },
            { id = "sync", name = "Sincronização", icon = "󰦗" },
        },
    },

    -- APARÊNCIA
    {
        id = 1,
        name = "Aparência",
        icon = "󰏘",
        category = "APARÊNCIA",
        desc = "Cores Matugen M3, estilos, fontes, glassmorphism e transparência",
        essential = true,
        tasks = {
            { id = "themes", name = "Temas & Paleta", icon = "󰏘" },
            { id = "glass", name = "Efeito de Vidro", icon = "󰤄" },
            { id = "typography", name = "Tipografia", icon = "󰬴" },
            { id = "radius", name = "Geometria", icon = "󰃚" },
        },
    },
    {
        id = 2,
        name = "Papel de Parede",
        icon = "󰸉",
        category = "APARÊNCIA",
        desc = "Backends swww/hyprpaper, efeitos de fundo, slideshow e blur",
        essential = false,
        tasks = {
            { id = "picker", name = "Seleção", icon = "󰸉" },
            { id = "effects", name = "Efeitos & Blur", icon = "󰛄" },
            { id = "slideshow", name = "Slideshow", icon = "󰑖" },
            { id = "backend", name = "Motor Gráfico", icon = "󰟢" },
        },
    },

    -- SHELL
    {
        id = 3,
        name = "Barra Superior",
        icon = "󰖯",
        category = "SHELL",
        desc = "Posicionamento da barra, auto-ocultação, módulos e bandeja",
        essential = true,
        tasks = {
            { id = "layout", name = "Posição & Altura", icon = "󰖯" },
            { id = "modules", name = "Módulos & Ordem", icon = "󰮄" },
            { id = "tray", name = "Bandeja (Tray)", icon = "󰒓" },
            { id = "autohide", name = "Auto-ocultação", icon = "󰘓" },
        },
    },
    {
        id = 4,
        name = "Dock Flutuante",
        icon = "󰀻",
        category = "SHELL",
        desc = "Dock estilo macOS / iPadOS, magnificação física, auto-ocultação e apps",
        essential = true,
        tasks = {
            { id = "style", name = "Estilo & Posição", icon = "󰀻" },
            { id = "magnify", name = "Magnificação", icon = "󰍉" },
            { id = "behavior", name = "Auto-ocultar", icon = "󰔡" },
            { id = "apps", name = "Apps Fixados", icon = "󰤱" },
        },
    },
    {
        id = 5,
        name = "App Launcher",
        icon = "󰍉",
        category = "SHELL",
        desc = "Menu de aplicativos, pesquisa fuzzy, categorias e ações rápidas",
        essential = true,
        tasks = {
            { id = "search", name = "Pesquisa & Fuzzy", icon = "󰍉" },
            { id = "grid", name = "Grade de Apps", icon = "󰮄" },
            { id = "actions", name = "Comandos Rápidos", icon = "󰘵" },
        },
    },
    {
        id = 6,
        name = "OSD & Avisos",
        icon = "󰕾",
        category = "SHELL",
        desc = "Indicadores visuais de volume, brilho, microfone e notificações toast",
        essential = false,
        tasks = {
            { id = "osd", name = "Indicadores OSD", icon = "󰕾" },
            { id = "notifications", name = "Notificações", icon = "󰂚" },
            { id = "dnd", name = "Não Perturbe", icon = "󰂛" },
        },
    },
    {
        id = 7,
        name = "Widgets & Módulos",
        icon = "󰮄",
        category = "SHELL",
        desc = "Relógio de cabeceira, clima, visualizador de áudio cava e monitor",
        essential = false,
        tasks = {
            { id = "desktop", name = "Widgets de Mesa", icon = "󰮄" },
            { id = "cava", name = "Visualizador CAVA", icon = "󰎈" },
            { id = "weather", name = "Clima & Previsão", icon = "󰖐" },
            { id = "clock", name = "Relógio & Data", icon = "󰥔" },
        },
    },

    -- SISTEMA
    {
        id = 8,
        name = "Sistema & Áudio",
        icon = "󰟢",
        category = "SISTEMA",
        desc = "Sinks PipeWire, proteção auditiva, microfone e luz noturna",
        essential = true,
        tasks = {
            { id = "audio", name = "Áudio & Volume", icon = "󰕾" },
            { id = "protection", name = "Proteção Auditiva", icon = "󰟢" },
            { id = "nightlight", name = "Luz Noturna", icon = "󰤄" },
        },
    },
    {
        id = 9,
        name = "Ferramentas & Captura",
        icon = "󰹑",
        category = "SISTEMA",
        desc = "Grim/Slurp screenshots, wf-recorder, OCR Tesseract e clipboard",
        essential = false,
        tasks = {
            { id = "screenshot", name = "Captura de Tela", icon = "󰹑" },
            { id = "recording", name = "Gravação de Vídeo", icon = "󰑋" },
            { id = "clipboard", name = "Clipboard Histórico", icon = "󰆏" },
            { id = "ocr", name = "Reconhecimento OCR", icon = "󰬴" },
        },
    },
    {
        id = 10,
        name = "Compositor & Janelas",
        icon = "󰨇",
        category = "SISTEMA",
        desc = "Gaps do Hyprland, bordas ativas, regras de janela, sombras e física",
        essential = true,
        tasks = {
            { id = "gaps", name = "Gaps & Margens", icon = "󰃚" },
            { id = "borders", name = "Bordas & Cores", icon = "󰏘" },
            { id = "animations", name = "Animações & Curvas", icon = "󰔡" },
            { id = "layout", name = "Dwindle / Master", icon = "󰖯" },
        },
    },
    {
        id = 15,
        name = "Bloqueio & Segurança",
        icon = "󰌾",
        category = "SISTEMA",
        desc = "Hyprlock, tempo de bloqueio por ociosidade, polkit e proteção de sessão",
        essential = false,
        tasks = {
            { id = "hyprlock", name = "Tela de Bloqueio", icon = "󰌾" },
            { id = "idle", name = "Tempo Limite / Idle", icon = "󰤄" },
            { id = "security", name = "Polkit & Autenticação", icon = "󰘵" },
        },
    },
    {
        id = 16,
        name = "Sobre o Zenith",
        icon = "󰌽",
        category = "SISTEMA",
        desc = "Versão do motor, runtime Luau, atalhos do teclado e diagnóstico",
        essential = true,
        tasks = {
            { id = "about", name = "Zenith Shell v0.2", icon = "󰌽" },
            { id = "cheatsheet", name = "Atalhos de Teclado", icon = "󰌌" },
            { id = "diagnostics", name = "Diagnóstico", icon = "󰘵" },
        },
    },

    -- HARDWARE
    {
        id = 11,
        name = "Telas & Monitores",
        icon = "󰍹",
        category = "HARDWARE",
        desc = "Monitores conectados, taxas de atualização, resolução e escalas",
        essential = true,
        tasks = {
            { id = "outputs", name = "Monitores Ativos", icon = "󰍹" },
            { id = "scale", name = "Escala Wayland", icon = "󰍉" },
            { id = "profiles", name = "Perfis de Tela", icon = "󰘵" },
        },
    },
    {
        id = 12,
        name = "Mídia & Sons",
        icon = "󰎈",
        category = "HARDWARE",
        desc = "Controles MPRIS Spotify/Browser, espectro sonoro e efeitos",
        essential = false,
        tasks = {
            { id = "players", name = "Reprodutores MPRIS", icon = "󰎈" },
            { id = "spectrum", name = "Espectro FFT", icon = "󰛄" },
        },
    },
    {
        id = 13,
        name = "Rede & Bluetooth",
        icon = "󰤨",
        category = "HARDWARE",
        desc = "Status de rede Wi-Fi/Ethernet, pareamento Bluetooth e dispositivos",
        essential = true,
        tasks = {
            { id = "network", name = "Conexões de Rede", icon = "󰤨" },
            { id = "bluetooth", name = "Dispositivos Bluetooth", icon = "󰂯" },
        },
    },
    {
        id = 14,
        name = "Energia & Bateria",
        icon = "󰁹",
        category = "HARDWARE",
        desc = "Perfis de consumo power-profiles-daemon, limites de bateria e suspensão",
        essential = true,
        tasks = {
            { id = "power", name = "Perfis de Energia", icon = "󰁹" },
            { id = "battery", name = "Avisos de Bateria", icon = "󰂃" },
            { id = "suspend", name = "Suspensão Automática", icon = "󰤄" },
        },
    },
}

-- Search filtering helper
local function search_pages(query: string): { NavigationItem }
    local q = string.lower(string.gsub(query, "^%s*(.-)%s*$", "%1"))
    if string.len(q) == 0 then
        return PAGES
    end

    local matches: { NavigationItem } = {}
    for _, p in ipairs(PAGES) do
        local name_match = string.find(string.lower(p.name), q, 1, true) ~= nil
        local desc_match = string.find(string.lower(p.desc), q, 1, true) ~= nil
        local cat_match = string.find(string.lower(p.category), q, 1, true) ~= nil
        local task_match = false
        for _, t in ipairs(p.tasks) do
            if string.find(string.lower(t.name), q, 1, true) ~= nil then
                task_match = true
                break
            end
        end

        if name_match or desc_match or cat_match or task_match then
            table.insert(matches, p)
        end
    end
    return matches
end

local function get_page_by_id(id: number): NavigationItem?
    for _, p in ipairs(PAGES) do
        if p.id == id then
            return p
        end
    end
    return PAGES[1]
end

-- Renders the Inir-style left Navigation Rail
local function SettingsNavigation(props: {
    active_page: number,
    search_query: string?,
    easy_mode: boolean?,
})
    local pal = Components.get_palette()
    local active_id = props.active_page
    local query = props.search_query or ""
    local is_easy = props.easy_mode or Store.get("settingsEasyMode", false)

    local visible_pages = if string.len(query) > 0 then search_pages(query) else PAGES

    local nav_children: { any } = {}
    local current_category = ""

    for _, p in ipairs(visible_pages) do
        if is_easy and not p.essential then
            continue
        end

        -- Category Header (all caps, small, bold, letter spaced)
        if string.len(query) == 0 and p.category ~= current_category then
            current_category = p.category
            table.insert(nav_children, Zenith.Box({
                padding = { left = 10, right = 10, top = 10, bottom = 4 },
                children = {
                    Zenith.Text({
                        text = current_category,
                        font_family = "Inter",
                        font_size = 10,
                        font_weight = "bold",
                        color = pal.colPrimary,
                        opacity = 0.85,
                    }),
                },
            }))
        end

        local is_active = p.id == active_id

        -- Inir Navigation Button with active accent strip and pill background
        table.insert(nav_children, Zenith.Box({
            direction = "row",
            align_items = "center",
            width = "100%",
            height = 36,
            padding = { horizontal = 8 },
            gap = 10,
            border_radius = 10,
            cursor = "pointer",
            background = if is_active then pal.colPrimaryContainer else Zenith.rgba(0, 0, 0, 0),
            border_width = 1,
            border_color = if is_active then pal.colPrimary else Zenith.rgba(0, 0, 0, 0),
            on_click = "settings:page:" .. tostring(p.id),
            children = {
                -- Active Left Indicator Strip (3px vertical accent)
                Zenith.Box({
                    width = 3,
                    height = 20,
                    border_radius = 2,
                    background = if is_active then pal.colPrimary else Zenith.rgba(0, 0, 0, 0),
                }),
                -- Page Icon
                Zenith.Text({
                    text = p.icon,
                    font_family = "JetBrainsMono Nerd Font",
                    font_size = 16,
                    color = if is_active then pal.colPrimary else pal.colSubtext,
                }),
                -- Page Name
                Zenith.Text({
                    text = p.name,
                    font_family = "Inter",
                    font_size = 12,
                    font_weight = if is_active then "semibold" else "normal",
                    color = if is_active then pal.colOnPrimaryContainer else pal.colOnSurface,
                }),
            },
        }))
    end

    -- Bottom Inir Actions Dock (Config File & Overlay Toggle)
    local bottom_actions = Zenith.Box({
        direction = "column",
        gap = 4,
        width = "100%",
        padding = { top = 10 },
        children = {
            Components.Divider(),
            -- Config file button
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                height = 32,
                padding = { horizontal = 10 },
                border_radius = 8,
                cursor = "pointer",
                on_click = "cmd:xdg-open ~/.config/zenith/config.json",
                tooltip = "Abrir Arquivo de Configuração (~/.config/zenith/config.json)",
                children = {
                    Zenith.Text({
                        text = "󰈔",
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 14,
                        color = pal.colSubtext,
                    }),
                    Zenith.Text({
                        text = "Arquivo de Config",
                        font_family = "Inter",
                        font_size = 11,
                        color = pal.colSubtext,
                    }),
                },
            }),
            -- Overlay mode button
            Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                height = 32,
                padding = { horizontal = 10 },
                border_radius = 8,
                cursor = "pointer",
                on_click = "settings:toggle_overlay",
                tooltip = "Alternar Modo Overlay da Shell",
                children = {
                    Zenith.Text({
                        text = "󰹑",
                        font_family = "JetBrainsMono Nerd Font",
                        font_size = 14,
                        color = pal.colSubtext,
                    }),
                    Zenith.Text({
                        text = "Modo Overlay",
                        font_family = "Inter",
                        font_size = 11,
                        color = pal.colSubtext,
                    }),
                },
            }),
        },
    })

    return Zenith.Box({
        direction = "column",
        justify_content = "space_between",
        width = 220,
        height = "100%",
        padding = 8,
        background = pal.colLayer1,
        border_width = 1,
        border_color = pal.colBorderSubtle,
        border_radius = 16,
        children = {
            -- Scrollable / stacked list of items
            Zenith.Box({
                direction = "column",
                gap = 2,
                width = "100%",
                children = nav_children,
            }),
            -- Bottom dock
            bottom_actions,
        },
    })
end

return {
    component = SettingsNavigation,
    pages = PAGES,
    search_pages = search_pages,
    get_page = get_page_by_id,
}
