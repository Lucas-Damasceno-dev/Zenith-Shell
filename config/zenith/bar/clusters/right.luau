--!strict
-- Zenith Desktop Shell — Bar Right Cluster
-- Orchestrates System Tray, Indicators, Status Pills and Power Actions

local Store = Zenith.import("core/store")
local Widgets = Zenith.import("widgets/init")

local function RightCluster(props: { compact: boolean?, zen_mode: boolean?, height: number? }?)
    local children = {}
    local is_zen = if props and props.zen_mode ~= nil then props.zen_mode else Store.get("barZenMode", false)
    local is_compact = if props and props.compact ~= nil then props.compact else Store.get("barCompactMode", false)

    if is_zen then
        -- Zen Mode: minimal clock & quick status
        table.insert(children, Widgets.QuickStatus({ show_actions = false }))
        return Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            children = children,
        })
    end

    if is_compact then
        -- Compact Mode: aggregated QuickStatus pill + Tray + Session
        if Store.get("showSystemTray", true) then
            local tray = Widgets.Tray()
            if tray then
                table.insert(children, tray)
            end
        end
        table.insert(children, Widgets.QuickStatus({ show_actions = true }))
        return Zenith.Box({
            direction = "row",
            align_items = "center",
            gap = 6,
            children = children,
        })
    end

    -- Full Desktop Cluster Mode
    if Store.get("showCavaVisualizer", true) then
        table.insert(children, Widgets.Cava())
    end

    if Store.get("showPrivacyIndicator", true) then
        table.insert(children, Widgets.Privacy())
    end

    if Store.get("showClipboardTile", true) then
        table.insert(children, Widgets.Clipboard())
    end

    if Store.get("showUsbWidget", true) then
        table.insert(children, Widgets.USB())
    end

    if Store.get("showSystemTray", true) then
        local tray = Widgets.Tray()
        if tray then
            table.insert(children, tray)
        end
    end

    if Store.get("showHardwareMonitors", true) then
        table.insert(children, Widgets.Hardware())
    end

    if Store.get("showNetworkStatus", true) then
        table.insert(children, Widgets.Network())
    end

    if Store.get("bluetoothEnabled", true) then
        table.insert(children, Widgets.Bluetooth())
    end

    if Store.get("showAudioStatus", true) then
        table.insert(children, Widgets.Audio())
    end

    if Store.get("showBatteryStatus", true) then
        table.insert(children, Widgets.Battery())
    end

    if Store.get("showKeyboardLayout", true) then
        table.insert(children, Widgets.Keyboard())
    end

    if Store.get("showCenterNotifications", true) then
        table.insert(children, Widgets.Notifications())
    end

    if Store.get("showSettingsHub", true) then
        table.insert(children, Widgets.SettingsHub())
    end

    if Store.get("showSessionButton", true) then
        table.insert(children, Widgets.Session())
    end

    return Zenith.Box({
        direction = "row",
        align_items = "center",
        justify_content = "flex_end",
        gap = 5,
        children = children,
    })
end

return RightCluster
