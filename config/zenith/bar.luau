--!strict
-- Zenith Desktop Shell — Main Status Bar Entrypoint
local Services = Zenith.import("core/services/init")
local PopupManager = Zenith.import("core/popup_manager")
local Bar = Zenith.import("bar/init")

Services.start()

return Bar()
