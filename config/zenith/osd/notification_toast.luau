--!strict
-- Zenith Desktop Shell — OSD Floating Notification Toast
-- Transient popup showing the most recent critical notification

local Theme = Zenith.import("core/theme")
local Services = Zenith.import("core/services/init")

local function NotificationToast(props: {
    summary: string?,
    body: string?,
    app_name: string?,
    id: number?,
}?)
    local theme = Theme.get()
    local notifs = Services.Notifications.list()
    local latest = if #notifs > 0 then notifs[1] else nil

    local summary = if props and props.summary then props.summary
        elseif latest and latest.summary ~= "" then latest.summary
        else "Notificação do Sistema"

    local body = if props and props.body then props.body
        elseif latest and latest.body ~= "" then latest.body
        else "Nenhuma nova notificação pendente"

    local app_name = if props and props.app_name then props.app_name
        elseif latest and latest.app_name ~= "" then latest.app_name
        else "Zenith"

    local notif_id = if props and props.id then props.id
        elseif latest then latest.id
        else 0

    return Zenith.Box({
        direction = "column",
        width = 320,
        padding = 14,
        border_radius = 18,
        background = Zenith.hex(theme.surface_container_highest or theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 60),
        border_width = 1,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 150),
            blur = 20,
            offset_x = 0,
            offset_y = 6,
        },
        gap = 6,
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                justify_content = "space_between",
                width = "100%",
                children = {
                    Zenith.Box({
                        direction = "row",
                        align_items = "center",
                        gap = 6,
                        children = {
                            Zenith.Text({ text = "󰂚", font_size = 14, color = Zenith.hex(theme.primary) }),
                            Zenith.Text({
                                text = app_name,
                                font_family = "Inter",
                                font_size = 11,
                                font_weight = "bold",
                                color = Zenith.hex(theme.primary),
                            }),
                        },
                    }),
                    Zenith.Box({
                        cursor = "pointer",
                        on_click = "notification:close:" .. tostring(notif_id),
                        padding = 2,
                        children = {
                            Zenith.Text({ text = "󰅖", font_size = 12, color = Zenith.hex(theme.on_surface_variant) }),
                        },
                    }),
                },
            }),
            Zenith.Text({
                text = summary,
                font_family = "Inter",
                font_size = 13,
                font_weight = "semibold",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = body,
                font_family = "Inter",
                font_size = 11,
                color = Zenith.hex(theme.on_surface_variant),
            }),
        },
    })
end

return NotificationToast
