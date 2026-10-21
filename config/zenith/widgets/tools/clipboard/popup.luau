--!strict
-- Zenith-Shell: Clipboard History Manager Popup

local function detect_category(text: string, is_img: boolean): string
    if is_img then
        return "image"
    end
    local t = text:match("^%s*(.-)%s*$") or text
    if t:find("^https?://") or t:find("^www%.") then
        return "url"
    end
    if t:find("^const%s") or t:find("^let%s") or t:find("^function%s")
        or t:find("^import%s") or t:find("^class%s") or t:find("^def%s")
        or t:find("^local%s") or t:find("^curl%s") or t:find("^nix")
        or t:find("^#!/") or t:find("^SELECT%s") or (t:find("^{") and t:find("}$"))
        or t:find("^git%s") or t:find("^cargo%s") or t:find("^npm%s")
        or t:find("^sudo%s") or t:find("^docker%s") or t:find("^pnpm%s") then
        return "code"
    end
    return "text"
end

local function category_icon(cat: string): string
    if cat == "image" then
        return "󰋩"
    elseif cat == "url" then
        return "󰌹"
    elseif cat == "code" then
        return "󰅩"
    else
        return "󰈙"
    end
end

local Theme = Zenith.import("core/theme")
local PopupManager = Zenith.import("core/popup_manager")

local function ClipboardPopup()
    local theme = Theme.get()
    local items = if Zenith.Services and Zenith.Services.ClipboardHistory then Zenith.Services.ClipboardHistory() else {}
    local search_term = (_G.__clipboard_search or ""):lower()
    local current_filter = _G.__clipboard_filter or "all"

    local filtered = {}
    for _, it in ipairs(items) do
        local raw = it.text or it.content or ""
        local is_img = it.is_image or false
        local cat = detect_category(raw, is_img)

        local match_cat = (current_filter == "all") or (cat == current_filter)
        local match_search = true
        if #search_term > 0 then
            match_search = raw:lower():find(search_term, 1, true) ~= nil
        end

        if match_cat and match_search then
            table.insert(filtered, {
                id = tostring(it.id or #filtered + 1),
                raw = raw,
                category = cat,
            })
        end
    end

    local item_cards = {}
    for idx, it in ipairs(filtered) do
        if idx <= 6 then
            local icon = category_icon(it.category)
            local preview = it.raw:gsub("[\n\r]+", " ")
            if #preview > 45 then
                preview = preview:sub(1, 42) .. "..."
            end

            table.insert(item_cards, Zenith.Box({
                direction = "row",
                align_items = "center",
                gap = 8,
                padding = { horizontal = 10, vertical = 8 },
                border_radius = 8,
                background = Zenith.hex(theme.surface_container, 140),
                border_color = Zenith.hex(theme.outline_variant or theme.outline, 35),
                border_width = 1,
                cursor = "pointer",
                on_click = string.format("clipboard:copy:%s", it.id),
                children = {
                    Zenith.Text({
                        text = icon,
                        font_size = 13,
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Text({
                        text = preview,
                        font_size = 11,
                        color = Zenith.hex(theme.on_surface),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 6, vertical = 2 },
                        border_radius = 4,
                        background = Zenith.hex(theme.surface_container_high or theme.surface_container),
                        on_click = string.format("clipboard:delete:%s", it.id),
                        children = {
                            Zenith.Text({ text = "󰅖", font_size = 10, color = Zenith.hex(theme.outline_variant or theme.outline) }),
                        }
                    })
                }
            }))
        end
    end

    if #item_cards == 0 then
        table.insert(item_cards, Zenith.Box({
            direction = "column",
            align_items = "center",
            justify_content = "center",
            height = 120,
            children = {
                Zenith.Text({
                    text = "󰅍 Nenhum item no histórico",
                    font_size = 12,
                    color = Zenith.hex(theme.outline_variant or theme.outline),
                })
            }
        }))
    end

    return Zenith.Box({
        direction = "column",
        width = 380,
        height = 420,
        padding = { horizontal = 16, vertical = 14 },
        gap = 10,
        background = Zenith.hex(theme.surface, 235),
        border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
        border_width = 1,
        border_radius = 16,
        shadow = {
            color = Zenith.rgba(0, 0, 0, 180),
            blur = 20,
            offset_x = 0,
            offset_y = 8,
        },
        children = {
            Zenith.Box({
                direction = "row",
                align_items = "center",
                children = {
                    Zenith.Text({
                        text = "󰅍 Área de Transferência",
                        font_size = 13,
                        font_weight = "bold",
                        color = Zenith.hex(theme.primary),
                    }),
                    Zenith.Box({ flex_grow = 1 }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 2 },
                        border_radius = 6,
                        background = Zenith.hex(theme.surface_container),
                        on_click = PopupManager.close_action(),
                        children = {
                            Zenith.Text({ text = "✕", font_size = 11, color = Zenith.hex(theme.on_surface) }),
                        }
                    }),
                }
            }),

            Zenith.Box({
                direction = "column",
                gap = 6,
                flex_grow = 1,
                children = item_cards,
            }),

            Zenith.Box({
                direction = "row",
                justify_content = "space_between",
                align_items = "center",
                padding = { horizontal = 4, vertical = 2 },
                children = {
                    Zenith.Text({
                        text = string.format("%d itens", #filtered),
                        font_size = 10,
                        color = Zenith.hex(theme.outline_variant or theme.outline),
                    }),
                    Zenith.Box({
                        padding = { horizontal = 8, vertical = 4 },
                        border_radius = 6,
                        background = Zenith.hex(theme.error or "#f38ba8", 30),
                        cursor = "pointer",
                        on_click = "cmd:cliphist wipe &",
                        children = {
                            Zenith.Text({
                                text = "Limpar Tudo",
                                font_size = 10,
                                color = Zenith.hex(theme.error or "#f38ba8"),
                            })
                        }
                    })
                }
            })
        }
    })
end

return ClipboardPopup
