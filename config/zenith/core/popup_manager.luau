--!strict
-- Zenith Desktop Shell — Central Overlay & Popup Manager
-- Zero-fork native action string generators and programmatic dismiss control

if _G.__zenith_popup_manager then
    return _G.__zenith_popup_manager
end

local PopupManager = {}

-- Native action string generators for direct use in `on_click`
function PopupManager.toggle_action(id: string): string
    return "popup:toggle:" .. id
end

function PopupManager.open_action(id: string): string
    return "popup:open:" .. id
end

function PopupManager.close_action(): string
    return "popup:close"
end

-- Programmatic close via in-process IPC socket
function PopupManager.close()
    if Zenith.close then
        Zenith.close()
    elseif Zenith.exec then
        Zenith.exec("zenith close")
    end
end

_G.__zenith_popup_manager = PopupManager
return PopupManager
