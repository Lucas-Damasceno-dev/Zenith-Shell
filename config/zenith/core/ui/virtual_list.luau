--!strict
-- Zenith Desktop Shell — Virtualized List Component
-- High-performance windowing list with O(visible) layout node recycling

local Theme = Zenith.import("core/theme")

export type VirtualListProps = {
    id: string?,
    items: { any },
    item_height: number,
    visible_height: number,
    scroll_offset: number?,
    width: (number | string)?,
    render_item: (item: any, index: number) -> any,
    empty_placeholder: string?,
}

local function VirtualList(props: VirtualListProps)
    local items = props.items or {}
    local item_h = props.item_height or 40
    local vis_h = props.visible_height or 300
    local t = Theme.get()

    if #items == 0 and props.empty_placeholder then
        return Zenith.Box({
            width = props.width or "100%",
            height = vis_h,
            align_items = "center",
            justify_content = "center",
            children = {
                Zenith.Text({
                    text = props.empty_placeholder,
                    font_family = "JetBrainsMono Nerd Font",
                    font_size = 13,
                    color = Theme.alpha(t.on_surface_variant or t.on_surface or "#ffffff", 140),
                }),
            },
        })
    end

    return Zenith.VirtualList({
        id = props.id,
        items = items,
        item_height = item_h,
        visible_height = vis_h,
        scroll_offset = props.scroll_offset or 0,
        render_item = props.render_item,
    })
end

return VirtualList
