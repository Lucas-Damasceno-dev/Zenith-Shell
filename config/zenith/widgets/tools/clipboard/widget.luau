--!strict
-- Zenith-Shell: Clipboard Status Widget

local Pill = Zenith.import("widgets/shared/pill/init")
local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

type ClipboardWidgetProps = {
    reactive: boolean?,
}

local function ClipboardWidget(props: ClipboardWidgetProps?)
    local theme = Theme.get()

    local clip_count: number? = nil
    local clip_status: string? = nil

    if Zenith.Storage and Zenith.Storage.get then
        local raw_count = Zenith.Storage.get("clipboard_count", nil) or Zenith.Storage.get("cliphist_count", nil)
        if type(raw_count) == "number" then
            clip_count = raw_count
        end
        local raw_status = Zenith.Storage.get("cliphist_status", nil) or Zenith.Storage.get("clipboard_status", nil)
        if type(raw_status) == "string" and #raw_status > 0 then
            clip_status = raw_status
        end
    end

    local status_line: string
    if clip_count ~= nil then
        if clip_count > 0 then
            status_line = string.format("• %d item(ns) copiado(s) no histórico", clip_count)
        else
            status_line = "• Histórico de cópias vazio"
        end
    elseif clip_status ~= nil then
        status_line = string.format("• Status cliphist: %s", clip_status)
    else
        status_line = "• Cliphist: Monitoramento ativo"
    end

    local tooltip = string.format(
        "Área de Transferência (Clipboard)\n%s\n• Clique: Abrir Histórico\n• Super+V: Acesso Rápido\n• Botão Direito: Limpar Histórico",
        status_line
    )

    local badge_text: string? = nil
    if clip_count ~= nil and clip_count > 0 then
        badge_text = tostring(clip_count)
    end

    return Pill({
        icon = "󰅍",
        icon_size = 12,
        icon_color = Zenith.hex(theme.primary),
        badge = badge_text,
        badge_color = Zenith.hex(theme.primary),
        height = 26,
        border_radius = 13,
        padding = { horizontal = 8, vertical = 2 },
        tooltip = tooltip,
        on_click = PopupManager.toggle_action("ClipboardPopup"),
        on_right_click = "cmd:cliphist wipe &",
    })
end

return ClipboardWidget
