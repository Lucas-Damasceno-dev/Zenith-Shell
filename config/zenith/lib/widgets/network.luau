--!strict
-- Zenith UI Kit - Network Status Component (Quickshell Parity)
-- Matches BarNetworkStatus.qml (WiFi / Ethernet state and popup trigger)

local Pill = Zenith.import("widgets/pill")

local function NetworkWidget()
    local theme = Zenith.Theme()
    local net = Zenith.Services.network()

    local is_connected = if net then (net.is_connected == true or net.connected == true) else false
    local net_type = if net and net.type then net.type else "none"
    local net_ssid = if net and net.ssid then net.ssid else ""

    local net_icon = if not is_connected then "󰤭" elseif net_type == "wifi" then "󰖩" else "󰈀"
    local net_color = if is_connected then Zenith.hex(theme.green or "#a6e3a1") else Zenith.hex(theme.error or "#e06c75")

    local screen = Zenith.Services.Screen and Zenith.Services.Screen() or { width = 1366 }
    local screen_w = screen.width or 1366
    local net_label = if screen_w < 1440 then nil elseif not is_connected then nil elseif #net_ssid > 0 then (if #net_ssid > 10 then net_ssid:sub(1, 8) .. ".." else net_ssid) else "Wired"

    local tooltip = (if is_connected then
        ("Rede: " .. (if #net_ssid > 0 then net_ssid else "Ethernet") .. " (" .. (net.ip or "Conectado") .. ")\n• Clique: Painel de Redes & Wi-Fi")
    else
        "Rede: Desconectado\n• Clique: Painel de Redes & Wi-Fi") .. "\n• Botão Direito: Alternar Wi-Fi"

    return Pill({
        icon = net_icon,
        icon_size = 12,
        icon_color = net_color,
        label = net_label,
        label_size = 11,
        height = 26,
        border_radius = 13,
        padding = { x = if net_label then 8 else 7, y = 2 },
        gap = 4,
        tooltip = tooltip,
        on_click = "popup:toggle:NetworkPopup",
        on_right_click = "wifi:toggle",
    })
end

return NetworkWidget
