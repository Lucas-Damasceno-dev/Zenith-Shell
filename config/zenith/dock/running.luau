--!strict
-- Zenith Desktop Shell — Running Applications Aggregator
-- Queries Compositor and Wayland Toplevel Protocols for open client instances

local Services = Zenith.import("core/services/init")

export type RunningApp = {
    class_name: string,
    title: string,
    address: string,
    is_active: boolean,
    instance_count: number,
    addresses: { string },
}

local RunningApps = {}

function RunningApps.get_active_apps(): { [string]: RunningApp }
    local clients = Services.Hyprland.clients()
    local app_map: { [string]: RunningApp } = {}

    for _, c in ipairs(clients) do
        local raw_class = c.class
        if raw_class and raw_class ~= "" then
            local key = string.lower(raw_class)
            if not app_map[key] then
                app_map[key] = {
                    class_name = raw_class,
                    title = c.title,
                    address = c.address,
                    is_active = c.focused or false,
                    instance_count = 1,
                    addresses = { c.address },
                }
            else
                local entry = app_map[key]
                entry.instance_count = entry.instance_count + 1
                table.insert(entry.addresses, c.address)
                if c.focused then
                    entry.is_active = true
                    entry.address = c.address
                    entry.title = c.title
                end
            end
        end
    end

    return app_map
end

return RunningApps
