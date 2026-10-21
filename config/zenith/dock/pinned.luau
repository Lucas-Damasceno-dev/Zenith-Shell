--!strict
-- Zenith Desktop Shell — Pinned Dock Applications Registry

local Store = Zenith.import("core/store")

export type PinnedApp = {
    id: string,
    name: string,
    exec: string,
    class_name: string,
    icon: string?,
}

local DEFAULT_PINNED: { PinnedApp } = {
    {
        id = "terminal",
        name = "Terminal",
        exec = Store.get("appTerminal", "foot"),
        class_name = "foot",
        icon = "󰞷",
    },
    {
        id = "browser",
        name = "Navegador Web",
        exec = Store.get("appBrowser", "firefox"),
        class_name = "firefox",
        icon = "󰈹",
    },
    {
        id = "file_manager",
        name = "Arquivos",
        exec = Store.get("appFileManager", "thunar"),
        class_name = "thunar",
        icon = "󰉋",
    },
    {
        id = "editor",
        name = "Editor de Código",
        exec = Store.get("appEditor", "codium"),
        class_name = "codium",
        icon = "󰨞",
    },
}

local PinnedApps = {}

function PinnedApps.list(): { PinnedApp }
    local stored = Store.get("dockPinnedApps", nil)
    if stored and type(stored) == "table" and #stored > 0 then
        return stored
    end
    return DEFAULT_PINNED
end

return PinnedApps
