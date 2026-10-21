--!strict
-- Zenith Desktop Shell — Master Single-Process Bootstrapper
-- Initializes reactive store, system services, popup manager and instantiates main status bar

local Store = Zenith.import("core/store")
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")
local Bar = Zenith.import("bar/init")

-- Initialize core runtime singletons in VM
Services.start()

-- Return primary status bar surface tree
return Bar()
