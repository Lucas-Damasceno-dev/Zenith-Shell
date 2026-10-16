--!strict
-- Zenith-Shell (Engine Base v3) - Wayland Clipboard Manager Overlay
-- 1:1 Parity with Quickshell ClipboardPopup: instant search, category filtering,
-- single-item deletion, two-step wipe, and theme-adaptive glassmorphism.

export type ClipItem = {
    id: string,
    raw: string,
    display: string,
    is_image: boolean,
    category: string,
}

-- ── 1. Helpers & Category Detection ───────────────────────────────

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

local function category_color(cat: string, theme: any): string
    if cat == "image" then
        return theme.tertiary or "#f5a97f"
    elseif cat == "url" then
        return theme.secondary or "#8bd5ca"
    elseif cat == "code" then
        return theme.primary or "#eed49f"
    else
        return theme.on_surface_variant or theme.outline or "#cad3f5"
    end
end

local function clamp(v: number, min: number, max: number): number
    if v < min then return min end
    if v > max then return max end
    return v
end

local function clean_snippet(text: string, max_len: number): string
    local single_line = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or text
    if #single_line > max_len then
        return single_line:sub(1, max_len - 3) .. "..."
    end
    return single_line
end

local function parse_cliphist(raw: string): { ClipItem }
    local items: { ClipItem } = {}
    for line in raw:gmatch("[^\r\n]+") do
        local id, content = line:match("^(%d+)%s*\t%s*(.*)$")
        if not id then
            id, content = line:match("^(%d+)%s+(.*)$")
        end
        if id and content and #content > 0 then
            local is_img = content:find("%[%[%s*binary%s*data") ~= nil or content:find("image/") ~= nil
            local cat = detect_category(content, is_img)
            local display = content
            if is_img then
                local mime = content:match("image/[%a%d%._%+-]+") or "PNG/JPG"
                display = string.format("[Imagem] %s", mime)
            else
                display = clean_snippet(content, 64)
            end
            table.insert(items, {
                id = id,
                raw = content,
                display = display,
                is_image = is_img,
                category = cat,
            })
        end
        if #items >= 100 then
            break
        end
    end
    return items
end

-- ── 2. Data Retrieval ─────────────────────────────────────────────

local theme = Zenith.Theme()
local query = Zenith.get_search_query()
local selected_idx = Zenith.get_selected_index()

-- Asynchronously refresh cliphist in the background if spawn primitive is present
if Zenith.spawn and not _G.__cliphist_loading then
    _G.__cliphist_loading = true
    Zenith.spawn(
        "bash",
        { "-c", "export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist list 2>/dev/null | head -n 100" },
        3000
    ):andThen(function(res)
        _G.__cliphist_loading = false
        if res and res.code == 0 and res.stdout and #res.stdout > 0 then
            _G.__cliphist_raw = res.stdout
            if Zenith.Storage and Zenith.Storage.set then
                Zenith.Storage.set("cliphist_raw", res.stdout)
            end
        end
    end):catch(function(_)
        _G.__cliphist_loading = false
    end)
end

local raw_data: string? = nil
if _G.__cliphist_raw and #_G.__cliphist_raw > 0 then
    raw_data = _G.__cliphist_raw
elseif Zenith.Storage and Zenith.Storage.get then
    local stored = Zenith.Storage.get("cliphist_raw", nil) or Zenith.Storage.get("clipboard_history", nil)
    if type(stored) == "string" and #stored > 0 then
        raw_data = stored
    end
end

-- Synchronous reading fallback when io.popen is available in sandbox
if not raw_data and (io :: any) and (io :: any).popen then
    pcall(function()
        local h = (io :: any).popen("export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist list 2>/dev/null | head -n 100")
        if h then
            local out = h:read("*a")
            h:close()
            if out and #out > 0 then
                raw_data = out
                _G.__cliphist_raw = out
            end
        end
    end)
end

local all_items: { ClipItem } = {}
if raw_data and #raw_data > 0 then
    all_items = parse_cliphist(raw_data)
elseif Zenith.Storage and Zenith.Storage.get then
    local stored_tbl = Zenith.Storage.get("clipboard_items", nil)
    if type(stored_tbl) == "table" and #stored_tbl > 0 then
        for _, it in ipairs(stored_tbl) do
            if type(it) == "table" and it.id and it.raw then
                local is_img = (it.is_image == true) or (it.raw:find("%[%[%s*binary%s*data") ~= nil)
                local cat = it.category or detect_category(it.raw, is_img)
                table.insert(all_items, {
                    id = tostring(it.id),
                    raw = tostring(it.raw),
                    display = tostring(it.display or it.raw),
                    is_image = is_img,
                    category = cat,
                })
            end
        end
    end
end

-- ── 3. Category Counts & Filtering ────────────────────────────────

local count_total = #all_items
local count_text = 0
local count_code = 0
local count_url = 0
local count_image = 0

for _, item in ipairs(all_items) do
    if item.category == "image" then
        count_image = count_image + 1
    elseif item.category == "code" then
        count_code = count_code + 1
    elseif item.category == "url" then
        count_url = count_url + 1
    else
        count_text = count_text + 1
    end
end

local active_category = "all"
if Zenith.Storage and Zenith.Storage.get then
    local st_cat = Zenith.Storage.get("clipboard_category", nil)
    if type(st_cat) == "string" and #st_cat > 0 then
        active_category = st_cat
    end
elseif _G.__clip_category then
    active_category = _G.__clip_category
end

local filtered_items: { ClipItem } = {}
local q_lower = query:lower():match("^%s*(.-)%s*$") or ""

for _, item in ipairs(all_items) do
    local match_cat = (active_category == "all") or (item.category == active_category)
    local match_q = (#q_lower == 0) or (item.raw:lower():find(q_lower, 1, true) ~= nil)
    if match_cat and match_q then
        table.insert(filtered_items, item)
    end
end

-- ── 4. Scrolling & Pagination ─────────────────────────────────────

local total_filtered = #filtered_items
local max_visible = 6

local function scroll_up()
    _G.__clip_scroll = math.max(0, (_G.__clip_scroll or 0) - 1)
end

local function scroll_down()
    local max_s = math.max(0, total_filtered - max_visible)
    _G.__clip_scroll = math.min(max_s, (_G.__clip_scroll or 0) + 1)
end

local cur_sel = selected_idx or 1
if total_filtered > 0 then
    if cur_sel > total_filtered then cur_sel = total_filtered end
    if cur_sel < 1 then cur_sel = 1 end
else
    cur_sel = 1
end

local start_idx = 1
if total_filtered > max_visible then
    start_idx = clamp(cur_sel - math.floor(max_visible / 2), 1, total_filtered - max_visible + 1)
    if _G.__clip_scroll ~= nil then
        local max_offset = math.max(0, total_filtered - max_visible)
        local manual_offset = clamp(_G.__clip_scroll, 0, max_offset)
        if cur_sel < manual_offset + 1 then
            manual_offset = cur_sel - 1
            _G.__clip_scroll = manual_offset
        elseif cur_sel > manual_offset + max_visible then
            manual_offset = cur_sel - max_visible
            _G.__clip_scroll = manual_offset
        end
        start_idx = manual_offset + 1
    end
end
local end_idx = math.min(start_idx + max_visible - 1, total_filtered)

-- ── 5. Component Construction: Category Tabs ──────────────────────

local categories = {
    { id = "all", label = "Todos", count = count_total, icon = "󰅍" },
    { id = "text", label = "Texto", count = count_text, icon = "󰈙" },
    { id = "code", label = "Código", count = count_code, icon = "󰅩" },
    { id = "url", label = "Links", count = count_url, icon = "󰌹" },
    { id = "image", label = "Imagens", count = count_image, icon = "󰋩" },
}

local category_chips = {}
for _, cat in ipairs(categories) do
    local is_active = (active_category == cat.id)
    local pill_text = string.format("%s %s (%d)", cat.icon, cat.label, cat.count)
    table.insert(category_chips, Zenith.Box({
        padding = { x = 8, y = 4 },
        border_radius = 6,
        background = is_active and Zenith.hex(theme.primary, 45) or Zenith.hex(theme.surface_container, 80),
        border_color = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.outline_variant or theme.outline, 40),
        border_width = 1,
        on_click = "storage:set:clipboard_category:" .. cat.id,
        children = {
            Zenith.Text({
                text = pill_text,
                font_size = 10,
                color = is_active and Zenith.hex(theme.primary) or Zenith.hex(theme.on_surface_variant or theme.on_surface),
            })
        }
    }))
end

-- ── 6. Component Construction: Item Cards ─────────────────────────

local item_boxes = {}
if total_filtered == 0 then
    local empty_title = if #query > 0
        then string.format("Nenhum resultado para '%s'", query)
        elseif count_total == 0
        then "Nenhum item copiado ainda"
        else string.format("Nenhum item na categoria '%s'", active_category:upper())

    local empty_subtitle = if #query > 0
        then "Tente buscar com outros termos ou selecione 'Todos'"
        else "Copie textos ou imagens para vê-los listados aqui"

    table.insert(item_boxes, Zenith.Box({
        direction = "column",
        align_items = "center",
        justify_content = "center",
        padding = { x = 20, y = 40 },
        gap = 8,
        border_radius = 12,
        background = Zenith.rgba(255, 255, 255, 6),
        border_color = Zenith.rgba(255, 255, 255, 12),
        border_width = 1,
        children = {
            Zenith.Text({
                text = "󰅍",
                font_size = 32,
                color = Zenith.hex(theme.outline, 160),
            }),
            Zenith.Text({
                text = empty_title,
                font_size = 13,
                font_weight = "bold",
                color = Zenith.hex(theme.on_surface),
            }),
            Zenith.Text({
                text = empty_subtitle,
                font_size = 11,
                color = Zenith.hex(theme.outline),
            }),
        }
    }))
else
    for idx = start_idx, end_idx do
        local item = filtered_items[idx]
        if not item then break end
        local is_selected = (idx == cur_sel)
        local cat_c = category_color(item.category, theme)
        local cat_i = category_icon(item.category)

        -- Copy and dismiss action command
        local copy_cmd = string.format(
            "launch:bash -c 'export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist decode %s | wl-copy'",
            item.id
        )

        -- Delete single item action command
        local del_cmd = string.format(
            "cmd:export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist list | awk -F'\\t' -v id=\"%s\" '$1 == id { print $0; exit }' | cliphist delete 2>/dev/null || true &",
            item.id
        )

        local sub_label = if item.is_image
            then "Imagem binária · Clique para copiar"
            else string.format("#%s · %s", item.id, item.category:upper())

        local item_font_size = if item.category == "code" then 11 else 12
        local item_font_family = if item.category == "code" then "monospace" else nil
        local sel_badge_text = if is_selected then "ENTER 󰆏" else "󰆏"
        local sel_badge_color = if is_selected then Zenith.hex(theme.on_primary) else Zenith.hex(theme.outline)

        table.insert(item_boxes, Zenith.Box({
            direction = "row",
            align_items = "center",
            padding = { x = 10, y = 7 },
            gap = 10,
            border_radius = 10,
            background = is_selected and Zenith.hex(theme.primary_container, 200) or Zenith.hex(theme.surface_container, 110),
            border_color = is_selected and Zenith.hex(theme.primary, 240) or Zenith.hex(theme.outline_variant or theme.outline, 45),
            border_width = 1,
            tooltip = "Clique para copiar este item ao clipboard",
            on_click = copy_cmd,
            children = {
                -- Category Icon Badge
                Zenith.Box({
                    width = 28,
                    height = 28,
                    border_radius = 6,
                    align_items = "center",
                    justify_content = "center",
                    background = Zenith.hex(cat_c, 35),
                    children = {
                        Zenith.Text({
                            text = cat_i,
                            font_size = 13,
                            color = Zenith.hex(cat_c),
                        })
                    }
                }),

                -- Snippet & Metadata
                Zenith.Box({
                    direction = "column",
                    align_items = "stretch",
                    gap = 2,
                    flex_grow = 1,
                    children = {
                        Zenith.Text({
                            text = item.display,
                            font_size = item_font_size,
                            font_family = item_font_family,
                            color = is_selected and Zenith.hex(theme.on_primary_container or theme.primary) or Zenith.hex(theme.on_surface),
                            truncate = true,
                        }),
                        Zenith.Text({
                            text = sub_label,
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),

                -- Enter / Copy indicator
                Zenith.Box({
                    padding = { x = 6, y = 2 },
                    border_radius = 4,
                    background = is_selected and Zenith.hex(theme.primary) or Zenith.rgba(255, 255, 255, 12),
                    children = {
                        Zenith.Text({
                            text = sel_badge_text,
                            font_size = 9,
                            color = sel_badge_color,
                        })
                    }
                }),

                -- Delete item button
                Zenith.Box({
                    width = 24,
                    height = 24,
                    border_radius = 4,
                    align_items = "center",
                    justify_content = "center",
                    background = Zenith.rgba(255, 255, 255, 10),
                    tooltip = "Remover item do histórico",
                    on_click = del_cmd,
                    children = {
                        Zenith.Text({
                            text = "󰅖",
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        })
                    }
                })
            }
        }))
    end
end

-- ── 7. Header Count & Dynamic Window Title ────────────────────────

local count_label = if count_total > 0
    then string.format("%d itens gravados • %d filtrado(s)", count_total, total_filtered)
    else "Histórico de cópias vazio"

-- Wipe history action command
local wipe_cmd = "cmd:export PATH=\"/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}\"; cliphist wipe 2>/dev/null || true &"

        -- ── Search Bar Input ─────────────────────────────────────
        local clear_btn = if #query > 0 then Zenith.Box({
            padding = { x = 5, y = 2 },
            border_radius = 4,
            background = Zenith.rgba(255, 255, 255, 12),
            tooltip = "Limpar busca",
            on_click = "search:clear",
            children = {
                Zenith.Text({ text = "󰅖", font_size = 10, color = Zenith.hex(theme.outline) }),
            }
        }) else nil

        local footer_text = if total_filtered > 0
            then string.format("󰌌 %d de %d itens • %d selecionado", total_filtered, count_total, cur_sel)
            else "0 itens encontrados"

        return Zenith.Window({
            direction = "column",
            align_items = "stretch",
            width = 440,
            height = 540,
            padding = { x = 16, y = 14 },
            gap = 10,
            background = Zenith.hex(theme.surface, 235),
            border_color = Zenith.hex(theme.outline_variant or theme.outline, 80),
            border_width = 1,
            border_radius = 16,
            on_scroll_up = scroll_up,
            on_scroll_down = scroll_down,
            shadow = {
                color = Zenith.rgba(0, 0, 0, 180),
                blur = 24,
                offset_x = 0,
                offset_y = 10,
            },
            children = {
                -- ── Header: Title, Item Counter & Action Buttons ──────────
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 10,
                    children = {
                        -- Icon Badge
                        Zenith.Box({
                            width = 32,
                            height = 32,
                            border_radius = 8,
                            align_items = "center",
                            justify_content = "center",
                            background = Zenith.hex(theme.primary, 35),
                            children = {
                                Zenith.Text({
                                    text = "󰅍",
                                    font_size = 16,
                                    color = Zenith.hex(theme.primary),
                                })
                            }
                        }),

                        -- Title & Item Count Subtitle
                        Zenith.Box({
                            direction = "column",
                            gap = 1,
                            flex_grow = 1,
                            children = {
                                Zenith.Text({
                                    text = "Área de Transferência",
                                    font_size = 13,
                                    font_weight = "bold",
                                    color = Zenith.hex(theme.on_surface),
                                }),
                                Zenith.Text({
                                    text = count_label,
                                    font_size = 10,
                                    color = Zenith.hex(theme.outline),
                                }),
                            }
                        }),

                        -- Wipe History Button
                        Zenith.Box({
                            direction = "row",
                            align_items = "center",
                            gap = 4,
                            padding = { x = 8, y = 4 },
                            border_radius = 6,
                            background = Zenith.rgba(239, 83, 80, 25),
                            border_color = Zenith.rgba(239, 83, 80, 80),
                            border_width = 1,
                            tooltip = "Limpar todo o histórico do clipboard (cliphist wipe)",
                            on_click = wipe_cmd,
                            children = {
                                Zenith.Text({
                                    text = "󰃢 Limpar",
                                    font_size = 10,
                                    color = Zenith.hex(theme.error or "#ef5350"),
                                })
                            }
                        }),

                        -- Close / ESC Button
                        Zenith.Box({
                            padding = { x = 8, y = 4 },
                            border_radius = 6,
                            background = Zenith.hex(theme.surface_container),
                            border_color = Zenith.rgba(255, 255, 255, 15),
                            border_width = 1,
                            tooltip = "Fechar pop-up (ESC)",
                            on_click = "popup:close",
                            children = {
                                Zenith.Text({
                                    text = "ESC",
                                    font_size = 9,
                                    color = Zenith.hex(theme.on_surface),
                                })
                            }
                        }),
                    }
                }),

                -- ── Search Bar Input ─────────────────────────────────────
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    padding = { x = 10, y = 6 },
                    border_radius = 10,
                    background = Zenith.hex(theme.surface_container),
                    border_color = Zenith.hex(theme.primary, 100),
                    border_width = 1,
                    gap = 8,
                    children = {
                        Zenith.Text({
                            text = "",
                            font_size = 13,
                            color = Zenith.hex(theme.primary),
                        }),
                        Zenith.Box({
                            flex_grow = 1,
                            children = {
                                Zenith.TextInput({
                                    id = "clipboard_search",
                                    placeholder = "Buscar no histórico...",
                                    text = query,
                                    active = true,
                                    font_size = 12,
                                    color = Zenith.hex(theme.on_surface),
                                })
                            }
                        }),
                        clear_btn,
                    }
                }),

                -- ── Category Filter Pills ────────────────────────────────
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    gap = 6,
                    children = category_chips,
                }),

                -- ── Clipboard Items List ─────────────────────────────────
                Zenith.Box({
                    direction = "column",
                    align_items = "stretch",
                    gap = 6,
                    flex_grow = 1,
                    on_scroll_up = scroll_up,
                    on_scroll_down = scroll_down,
                    children = item_boxes,
                }),

                -- ── Footer Status & Navigation Shortcuts ─────────────────
                Zenith.Box({
                    direction = "row",
                    align_items = "center",
                    padding = { x = 4, y = 2 },
                    children = {
                        Zenith.Text({
                            text = footer_text,
                            font_size = 10,
                            color = Zenith.hex(theme.outline),
                        }),
                        Zenith.Box({ flex_grow = 1 }),
                        Zenith.Text({
                            text = "↑/↓ Navegar • Enter Copiar • Esc Fechar",
                            font_size = 9,
                            color = Zenith.hex(theme.outline),
                        }),
                    }
                }),
            }
        })
