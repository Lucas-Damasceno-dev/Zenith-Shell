--!strict
-- Zenith Desktop Shell — Core Universal Contracts & Types
-- Standard interface binding reactive state, widgets, services and popovers

export type Signal<T> = {
    get: (self: Signal<T>) -> T,
    set: (self: Signal<T>, newValue: T) -> (),
    subscribe: (self: Signal<T>, callback: (T) -> ()) -> () -> (),
}

export type WidgetProps = {
    [string]: any,
}

-- Universal Widget Module Contract (co-located widget + popup)
export type WidgetModule = {
    id: string,
    widget: (props: WidgetProps?) -> any,
    popup: (() -> any)?,
    on_mount: (() -> ())?,
    on_unmount: (() -> ())?,
}

-- Core Service Contract (lazy-loaded singletons)
export type Service = {
    name: string,
    start: (self: Service) -> (),
    stop: (self: Service) -> (),
    is_running: boolean,
}

-- Popup / Overlay Manager Contract
export type PopupState = {
    active_popup: string?,
    toggle: (id: string) -> (),
    open: (id: string) -> (),
    close: () -> (),
    is_open: (id: string) -> boolean,
}

return nil
