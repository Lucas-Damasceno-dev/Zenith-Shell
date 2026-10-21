--!strict
-- Zenith Desktop Shell — Semantic Nerd Fonts & Glyph Resolver
-- High-density icon mapping for JetBrainsMono Nerd Font and App Resolver

local Icons = {}

-- ═════════════════════════════════════════════════════════════════
-- 1. APPLICATION ICON OVERRIDES (XDG Window Class & Title Heuristics)
-- ═════════════════════════════════════════════════════════════════
local APP_ICON_MAP = {
    -- Terminal Emulators
    foot        = "",
    kitty       = "",
    alacritty   = "",
    wezterm     = "",
    ghostty     = "",
    urxvt       = "",
    xterm       = "",
    termite     = "",

    -- Web Browsers
    brave       = "󰖟",
    firefox     = "󰈹",
    zen         = "󰈹",
    chrome      = "",
    chromium    = "",
    edge        = "󰇩",

    -- Code Editors & IDEs
    code        = "󰨞",
    vscode      = "󰨞",
    vscodium    = "󰨞",
    codium      = "󰨞",
    zed         = "󰨞",
    cursor      = "󰨞",
    neovim      = "",
    nvim        = "",
    emacs       = "",

    -- File Managers
    thunar      = "󰉋",
    dolphin     = "󰉋",
    nautilus    = "󰉋",
    pcmanfm     = "󰉋",

    -- Media & Entertainment
    spotify     = "󰓇",
    vlc         = "󰕼",
    mpv         = "",
    obs         = "󰐌",

    -- Communication
    discord     = "󰭹",
    vesktop     = "󰭹",
    telegram    = "",
    slack       = "󰒱",
    signal      = "󰈹",

    -- Graphics & Design
    gimp        = "",
    inkscape    = "",
    blender     = "󰂫",
    figma       = "",
}

-- ═════════════════════════════════════════════════════════════════
-- 2. SEMANTIC GLYPH CATALOG
-- ═════════════════════════════════════════════════════════════════
Icons.glyphs = {
    launcher        = "",
    settings        = "󰒓",
    power           = "󰐥",
    reboot          = "󰜉",
    lock            = "󰌾",
    logout          = "󰍃",
    suspend         = "󰤄",
    hibernate       = "󰒲",
    terminal        = "",
    files           = "󰉋",
    browser         = "󰈹",
    code            = "󰨞",
    search          = "󰍉",
    close           = "󰅖",
    minimize        = "󰖰",
    maximize        = "󰖲",
    pin             = "󰤱",
    unpin           = "󰤰",
    trash           = "󰩺",
    trash_full      = "󰩻",
    overview        = "󰕰",
    keyboard        = "󰌌",
    screen_record   = "󰑋",
    screenshot      = "󰹑",
    clipboard       = "󰆏",
    chevron_right   = "󰅂",
    chevron_left    = "󰅁",
    chevron_down    = "󰅀",
    chevron_up      = "󰅃",
    check           = "󰄬",
    alert           = "󰀦",
    info            = "󰋼",
    clock           = "",
    calendar        = "󰸗",

    play            = "󰐊",
    pause           = "󰏤",
    next            = "󰒭",
    prev            = "󰒮",
    stop            = "󰓛",
    shuffle         = "󰒝",
    repeat_track    = "󰑖",
    music           = "󰎆",
    volume_high     = "󰕾",
    volume_med      = "󰖀",
    volume_low      = "󰕿",
    volume_mute     = "󰝟",
    volume_muted    = "󰝟",
    mic             = "󰍬",
    mic_muted       = "󰍭",

    wifi            = "󰖩",
    wifi_full       = "󰖩",
    wifi_med        = "󰖨",
    wifi_low        = "󰖥",
    wifi_off        = "󰖪",
    wifi_disconnected = "󰖪",
    ethernet        = "󰈀",
    bluetooth       = "󰂯",
    bluetooth_off   = "󰂲",
    bluetooth_conn  = "󰂱",
    battery_100     = "󰁹",
    battery_90      = "󰂂",
    battery_80      = "󰂁",
    battery_70      = "󰂀",
    battery_60      = "󰁿",
    battery_50      = "󰁾",
    battery_40      = "󰁽",
    battery_30      = "󰁼",
    battery_20      = "󰁻",
    battery_10      = "󰁺",
    battery_empty   = "󰂃",
    battery_charging= "󰂄",
    battery_alert   = "󰂃",
    cpu             = "󰘚",
    memory          = "󰍛",
    disk            = "󰋊",
    gpu             = "󰢮",
    temp            = "󰔏",
    brightness      = "󰃠",
    brightness_low  = "󰃞",

    bell            = "󰂚",
    bell_dnd        = "󰂛",
    bell_badge      = "󰂞",
    weather_sun     = "󰖙",
    weather_cloud   = "󰖐",
    weather_rain    = "󰖗",
    weather_snow    = "󰖘",
    weather_storm   = "󰖒",
}

function Icons.get(key: string, fallback: string?): string
    return Icons.glyphs[key] or fallback or Icons.glyphs.info or "?"
end

function Icons.for_app(class_name: string?, title: string?): string
    local search_str = string.lower(string.format("%s %s", class_name or "", title or ""))
    for app_key, glyph in pairs(APP_ICON_MAP) do
        if string.find(search_str, app_key) then
            return glyph
        end
    end
    return Icons.glyphs.terminal
end

function Icons.battery(percentage: number, is_charging: boolean): string
    if is_charging then
        return Icons.glyphs.battery_charging
    elseif percentage > 85 then
        return Icons.glyphs.battery_100
    elseif percentage > 65 then
        return Icons.glyphs.battery_80
    elseif percentage > 45 then
        return Icons.glyphs.battery_60
    elseif percentage > 25 then
        return Icons.glyphs.battery_40
    elseif percentage > 10 then
        return Icons.glyphs.battery_20
    else
        return Icons.glyphs.battery_empty
    end
end

function Icons.volume(level: number, is_muted: boolean): string
    if is_muted or level <= 0 then
        return Icons.glyphs.volume_muted
    elseif level > 60 then
        return Icons.glyphs.volume_high
    elseif level > 25 then
        return Icons.glyphs.volume_med
    else
        return Icons.glyphs.volume_low
    end
end

-- Flexible WiFi resolver supporting (strength, connected) and (connected, strength)
function Icons.wifi(arg1: any, arg2: any): string
    local is_connected = false
    local strength = 100

    if typeof(arg1) == "boolean" then
        is_connected = arg1
        strength = if typeof(arg2) == "number" then arg2 else 100
    elseif typeof(arg1) == "number" then
        strength = arg1
        is_connected = if typeof(arg2) == "boolean" then arg2 else true
    end

    if not is_connected then
        return Icons.glyphs.wifi_disconnected
    elseif strength > 70 then
        return Icons.glyphs.wifi_full
    elseif strength > 35 then
        return Icons.glyphs.wifi_med
    else
        return Icons.glyphs.wifi_low
    end
end

Icons.typography = {
    fonts = {
        ui    = "Inter",
        mono  = "JetBrainsMono Nerd Font",
        icons = "JetBrainsMono Nerd Font",
    },
    scale = {
        hero       = { size = 32, weight = "bold",   line_height = 1.1, baseline_offset = 0 },
        headline   = { size = 18, weight = "bold",   line_height = 1.2, baseline_offset = 0 },
        title      = { size = 14, weight = "medium", line_height = 1.3, baseline_offset = 0 },
        body_large = { size = 13, weight = "normal", line_height = 1.4, baseline_offset = 0 },
        body       = { size = 12, weight = "normal", line_height = 1.4, baseline_offset = 0 },
        body_small = { size = 11, weight = "normal", line_height = 1.3, baseline_offset = 0 },
        caption    = { size = 10, weight = "normal", line_height = 1.2, baseline_offset = 0 },
        mono_time  = { size = 12, weight = "bold",   line_height = 1.0, baseline_offset = 0 },
        icon_sm    = { size = 12, weight = "normal", line_height = 1.0, baseline_offset = 1 },
        icon_md    = { size = 15, weight = "normal", line_height = 1.0, baseline_offset = 1 },
        icon_lg    = { size = 18, weight = "normal", line_height = 1.0, baseline_offset = 1 },
        icon_dock  = { size = 20, weight = "normal", line_height = 1.0, baseline_offset = 0 },
    },
}

return Icons
