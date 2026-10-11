pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property var categories: [
        {
            key: "essentials",
            label: "Essentials",
            pages: [0]
        },
        {
            key: "appearance",
            label: "Appearance",
            pages: [4, 3]
        },
        {
            key: "shell",
            label: "Shell UI",
            pages: [2, 6, 5, 11, 13]
        },
        {
            key: "system",
            label: "System & Core",
            pages: [1, 9, 8, 7, 10, 12]
        },
        {
            key: "reference",
            label: "Reference & Maintenance",
            pages: [15, 14, 16]
        }
    ]

    readonly property var pages: [
        {
            key: "quick",
            name: "Quick",
            icon: "\uf0e7", // bolt
            desc: "Wallpaper, presets & quick toggles",
            essential: true,
            component: Qt.resolvedUrl("pages/QuickConfig.qml")
        },
        {
            key: "system",
            name: "System",
            icon: "\uf1de", // sliders / tune
            desc: "Audio, battery, night light & hyprlock",
            essential: true,
            component: Qt.resolvedUrl("pages/SystemConfig.qml")
        },
        {
            key: "bar",
            name: "Bar",
            icon: "\uf2d0", // window-maximize
            desc: "Position, auto-hide, modules & tray",
            essential: true,
            component: Qt.resolvedUrl("pages/BarConfig.qml")
        },
        {
            key: "wallpaper",
            name: "Wallpaper",
            icon: "\uf03e", // image
            desc: "Engine, slideshow & effects",
            essential: false,
            component: Qt.resolvedUrl("pages/WallpaperConfig.qml")
        },
        {
            key: "themes",
            name: "Themes & Style",
            icon: "\uf53f", // palette
            desc: "Colors, typography, borders & physics",
            essential: true,
            component: Qt.resolvedUrl("pages/ThemesConfig.qml")
        },
        {
            key: "panels",
            name: "Panels",
            icon: "\uf009", // th-large / grid
            desc: "Overview, expose & hot corners",
            essential: true,
            component: Qt.resolvedUrl("pages/PanelsConfig.qml")
        },
        {
            key: "dock",
            name: "Dock",
            icon: "\uf2d2", // window-restore
            desc: "Dock size, pinned apps & behavior",
            essential: true,
            component: Qt.resolvedUrl("pages/DockConfig.qml")
        },
        {
            key: "tools",
            name: "Tools & Capture",
            icon: "\uf030", // camera
            desc: "Recording, screenshot, OCR & lens",
            essential: false,
            component: Qt.resolvedUrl("pages/ToolsConfig.qml")
        },
        {
            key: "services",
            name: "Services",
            icon: "\uf0c2", // cloud
            desc: "Weather, media player & default apps",
            essential: false,
            component: Qt.resolvedUrl("pages/ServicesConfig.qml")
        },
        {
            key: "compositor",
            name: "Compositor",
            icon: "\uf108", // desktop
            desc: "Hyprland animations, gaps & input",
            essential: false,
            component: Qt.resolvedUrl("pages/CompositorConfig.qml")
        },
        {
            key: "ai",
            name: "AI & Copilot",
            icon: "\uf544", // robot
            desc: "Providers, models, prompt & voice",
            essential: false,
            component: Qt.resolvedUrl("pages/AiConfig.qml")
        },
        {
            key: "dashboard",
            name: "Dashboard",
            icon: "\uf0e4", // tachometer / dashboard
            desc: "Welcome hub, greetings & widgets",
            essential: false,
            component: Qt.resolvedUrl("pages/DashboardConfig.qml")
        },
        {
            key: "autostart",
            name: "Autostart",
            icon: "\uf135", // rocket
            desc: "Manage startup apps & daemons",
            essential: false,
            component: Qt.resolvedUrl("pages/AutostartConfig.qml")
        },
        {
            key: "modules",
            name: "Modules",
            icon: "\uf12e", // puzzle-piece
            desc: "Master switches for shell features",
            essential: true,
            component: Qt.resolvedUrl("pages/ModulesConfig.qml")
        },
        {
            key: "advanced",
            name: "Advanced",
            icon: "\uf0ad", // wrench
            desc: "Performance, memory & config JSON",
            essential: false,
            component: Qt.resolvedUrl("pages/AdvancedConfig.qml")
        },
        {
            key: "shortcuts",
            name: "Shortcuts",
            icon: "\uf11c", // keyboard
            desc: "Keybindings reference & actions",
            essential: true,
            component: Qt.resolvedUrl("pages/ShortcutsConfig.qml")
        },
        {
            key: "about",
            name: "About",
            icon: "\uf05a", // info-circle
            desc: "Zenith Shell info & diagnostics",
            essential: true,
            component: Qt.resolvedUrl("pages/AboutConfig.qml")
        }
    ]

    readonly property var searchDatabase: [
        { pageIndex: 0, label: "Wallpaper Path", section: "Quick Tweaks", keywords: ["background", "image", "wallpaper"] },
        { pageIndex: 0, label: "Layout Preset", section: "Quick Tweaks", keywords: ["layout", "compact", "floating", "style"] },
        { pageIndex: 0, label: "Bar Auto-Hide", section: "Quick Toggles", keywords: ["bar", "autohide", "toggle", "hide"] },
        { pageIndex: 0, label: "Compact Bar Mode", section: "Quick Toggles", keywords: ["bar", "compact", "height", "slim"] },
        { pageIndex: 0, label: "Reduced Motion", section: "Quick Toggles", keywords: ["animation", "motion", "disable", "fast"] },
        { pageIndex: 0, label: "Privacy Mode", section: "Quick Toggles", keywords: ["privacy", "anonymize", "hide", "blur"] },
        { pageIndex: 0, label: "Focus Mode", section: "Quick Toggles", keywords: ["focus", "dnd", "distraction", "zen"] },
        { pageIndex: 0, label: "Low Power Mode", section: "Quick Toggles", keywords: ["battery", "eco", "power", "saver"] },

        { pageIndex: 1, label: "Default Audio Sink", section: "Audio", keywords: ["sound", "sink", "speaker", "output", "headphones"] },
        { pageIndex: 1, label: "Default Audio Source", section: "Audio", keywords: ["microphone", "source", "input", "mic"] },
        { pageIndex: 1, label: "Audio Volume Step", section: "Audio", keywords: ["volume", "step", "percentage", "delta"] },
        { pageIndex: 1, label: "Battery Charge Limit", section: "Power & Battery", keywords: ["battery", "limit", "health", "80%"] },
        { pageIndex: 1, label: "Low Battery Threshold", section: "Power & Battery", keywords: ["battery", "threshold", "low", "notify"] },
        { pageIndex: 1, label: "Power Profile", section: "Power & Battery", keywords: ["powerprofilesctl", "performance", "balanced", "powersave"] },
        { pageIndex: 1, label: "Auto Suspend Timeout", section: "Power & Battery", keywords: ["suspend", "sleep", "timeout", "idle"] },
        { pageIndex: 1, label: "Night Light", section: "Display & Security", keywords: ["temperature", "kelvin", "blue", "night", "gamma"] },
        { pageIndex: 1, label: "Hyprlock Blur & Dim", section: "Display & Security", keywords: ["lockscreen", "hyprlock", "security", "blur"] },
        { pageIndex: 1, label: "Time & Date Format", section: "Locale & Time", keywords: ["clock", "date", "24h", "12h", "seconds"] },

        { pageIndex: 2, label: "Bar Position", section: "Geometry", keywords: ["bar", "top", "bottom", "dock"] },
        { pageIndex: 2, label: "Bar Height", section: "Geometry", keywords: ["height", "pixels", "size", "expanded"] },
        { pageIndex: 2, label: "Corner Style", section: "Geometry", keywords: ["floating", "rounded", "square", "edge"] },
        { pageIndex: 2, label: "Center Modules", section: "Modules", keywords: ["media", "clock", "weather", "notifications"] },
        { pageIndex: 2, label: "System Tray Monochome", section: "Tray", keywords: ["tray", "statusnotifier", "icons", "monochrome"] },

        { pageIndex: 3, label: "Wallpaper Backend", section: "Engine", keywords: ["swww", "hyprpaper", "mpvpaper", "engine"] },
        { pageIndex: 3, label: "Wallpaper Slideshow", section: "Engine", keywords: ["slideshow", "timer", "interval", "random"] },
        { pageIndex: 3, label: "Pause on Battery", section: "Effects", keywords: ["battery", "pause", "video", "animated"] },

        { pageIndex: 4, label: "Matugen Color Scheme", section: "Colors", keywords: ["matugen", "palette", "tonal_spot", "vibrant", "expressive"] },
        { pageIndex: 4, label: "Accent Color Override", section: "Colors", keywords: ["accent", "hex", "custom", "primary"] },
        { pageIndex: 4, label: "UI Font Family", section: "Typography", keywords: ["font", "inter", "typeface", "text"] },
        { pageIndex: 4, label: "Monospace Font", section: "Typography", keywords: ["font", "nerd", "mono", "jetbrains"] },
        { pageIndex: 4, label: "Corner Radius Scale", section: "Geometry", keywords: ["radius", "round", "corners", "sharp"] },
        { pageIndex: 4, label: "Motion Spring Physics", section: "Animations", keywords: ["spring", "physics", "damping", "stiffness"] },

        { pageIndex: 5, label: "Overview Columns & Rows", section: "Overview", keywords: ["overview", "workspace", "grid", "thumbnails"] },
        { pageIndex: 5, label: "Hot Corners Action", section: "Hot Corners", keywords: ["corner", "hotcorner", "gesture", "trigger"] },
        { pageIndex: 5, label: "Workspace Strip", section: "Workspace Strip", keywords: ["strip", "edge", "dock", "workspaces"] },

        { pageIndex: 6, label: "Dock Position & Height", section: "Appearance", keywords: ["dock", "bottom", "left", "height", "glass"] },
        { pageIndex: 6, label: "Dock Pinned Apps", section: "Pinned Applications", keywords: ["dock", "pinned", "apps", "favorites"] },
        { pageIndex: 6, label: "Autohide & Hover Reveal", section: "Behavior", keywords: ["dock", "autohide", "hover", "reveal"] },

        { pageIndex: 7, label: "Screen Recorder Codec & FPS", section: "Recording", keywords: ["record", "video", "fps", "h264", "wf-recorder"] },
        { pageIndex: 7, label: "Screenshot Format & Mode", section: "Screenshot", keywords: ["screenshot", "grim", "slurp", "png", "area"] },
        { pageIndex: 7, label: "OCR Language", section: "OCR & Lens", keywords: ["ocr", "tesseract", "lens", "translate"] },
        { pageIndex: 7, label: "Crosshair Overlay", section: "Gaming", keywords: ["crosshair", "fps", "game", "overlay"] },

        { pageIndex: 8, label: "Weather Provider & City", section: "Weather", keywords: ["weather", "temperature", "wttr", "location"] },
        { pageIndex: 8, label: "Audio Spectrum Visualizer", section: "Media", keywords: ["spectrum", "visualizer", "audio", "cava"] },
        { pageIndex: 8, label: "Default Applications", section: "Defaults", keywords: ["terminal", "browser", "editor", "filemanager"] },

        { pageIndex: 9, label: "Hyprland Layout (Dwindle/Master)", section: "Layout", keywords: ["hyprland", "layout", "dwindle", "master"] },
        { pageIndex: 9, label: "Gaps & Borders", section: "Appearance", keywords: ["gaps", "border", "active", "inactive"] },
        { pageIndex: 9, label: "Touchpad Gestures & Speed", section: "Input", keywords: ["touchpad", "scroll", "sensitivity", "cursor"] },

        { pageIndex: 10, label: "AI Provider & Model", section: "Model Configuration", keywords: ["gemini", "groq", "openai", "ollama", "llm"] },
        { pageIndex: 10, label: "AI System Prompt", section: "Prompt", keywords: ["system", "prompt", "instructions", "behavior"] },
        { pageIndex: 10, label: "Voice Search & Transcription", section: "Voice", keywords: ["voice", "whisper", "speech", "transcribe"] },

        { pageIndex: 11, label: "Dashboard Hub Enable", section: "Dashboard", keywords: ["dashboard", "welcome", "power", "header"] },
        { pageIndex: 11, label: "Dashboard Widgets", section: "Widgets", keywords: ["notes", "weather", "system", "quicknotes"] },

        { pageIndex: 12, label: "Startup Applications", section: "Autostart", keywords: ["autostart", "startup", "boot", "daemons"] },

        { pageIndex: 13, label: "Master Module Toggles", section: "Shell Features", keywords: ["modules", "enable", "disable", "bar", "dock"] },

        { pageIndex: 14, label: "JS GC Threshold", section: "Performance", keywords: ["memory", "ram", "gc", "garbage", "cache"] },
        { pageIndex: 14, label: "Reset to Defaults", section: "Maintenance", keywords: ["reset", "factory", "defaults", "clean"] },
        { pageIndex: 14, label: "Export / Import Config JSON", section: "JSON Data", keywords: ["json", "export", "import", "backup"] },

        { pageIndex: 15, label: "Hyprland Keybindings", section: "Keybindings", keywords: ["keybinds", "super", "shortcuts", "hotkeys"] },

        { pageIndex: 16, label: "Zenith Shell Engine v2", section: "Information", keywords: ["version", "diagnostics", "health", "system"] }
    ]

    function search(query) {
        var q = String(query || "").trim().toLowerCase();
        if (q.length === 0) return [];
        var results = [];
        for (var i = 0; i < searchDatabase.length; i++) {
            var item = searchDatabase[i];
            var match = false;
            if (item.label.toLowerCase().indexOf(q) !== -1) match = true;
            else if (item.section.toLowerCase().indexOf(q) !== -1) match = true;
            else {
                for (var k = 0; k < item.keywords.length; k++) {
                    if (item.keywords[k].toLowerCase().indexOf(q) !== -1) {
                        match = true;
                        break;
                    }
                }
            }
            if (match) {
                var page = pages[item.pageIndex];
                results.push({
                    pageIndex: item.pageIndex,
                    pageName: page.name,
                    pageIcon: page.icon,
                    section: item.section,
                    label: item.label
                });
            }
        }
        return results;
    }
}
