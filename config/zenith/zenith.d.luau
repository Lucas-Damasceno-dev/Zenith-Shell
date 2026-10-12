--!strict
-- Zenith Desktop Shell Framework — Luau Type Definitions (zenith.d.luau)

export type FlexDirection = "row" | "column" | "row_reverse" | "column_reverse"
export type JustifyContent = "flex_start" | "center" | "flex_end" | "space_between" | "space_around" | "space_evenly"
export type AlignItems = "flex_start" | "center" | "flex_end" | "stretch"
export type CursorType = "default" | "pointer" | "text" | "grab" | "grabbing"

export type PaddingSpec = number | {
    horizontal: number?,
    vertical: number?,
    left: number?,
    right: number?,
    top: number?,
    bottom: number?,
}

export type ShadowSpec = {
    color: string,
    blur: number,
    offset_x: number?,
    offset_y: number?,
    spread: number?,
}

export type BoxProps = {
    id: string?,
    width: (number | string)?,
    height: (number | string)?,
    flex_direction: FlexDirection?,
    justify_content: JustifyContent?,
    align_items: AlignItems?,
    gap: number?,
    padding: PaddingSpec?,
    background: string?,
    border_radius: number?,
    border_width: number?,
    border_color: string?,
    shadow: ShadowSpec?,
    shader: string?,
    uniforms: { [string]: number }?,
    opacity: number?,
    cursor: CursorType?,
    on_click: (() -> ())?,
    on_right_click: (() -> ())?,
    children: { any }?,
}

export type TextProps = {
    id: string?,
    text: string | any,
    color: string?,
    font_size: number?,
    font_weight: ("normal" | "medium" | "semibold" | "bold")?,
    font_family: string?,
    line_height: number?,
    opacity: number?,
    max_width: number?,
    truncate: boolean?,
}

export type ImageProps = {
    id: string?,
    src: string,
    width: number,
    height: number,
    opacity: number?,
    border_radius: number?,
}

export type ShaderProps = {
    id: string?,
    fragment: string,
    width: (number | string)?,
    height: (number | string)?,
    uniforms: { [string]: number }?,
    border_radius: number?,
    opacity: number?,
}

export type TextInputProps = {
    id: string?,
    placeholder: string?,
    text: string | any,
    color: string?,
    font_size: number?,
    active: boolean?,
    on_change: ((newText: string) -> ())?,
    on_submit: ((submittedText: string) -> ())?,
}

export type SliderProps = {
    id: string?,
    min: number?,
    max: number?,
    value: number?,
    track_height: number?,
    thumb_radius: number?,
    track_color: string?,
    active_track_color: string?,
    thumb_color: string?,
    on_change: ((newValue: number) -> ())?,
}

export type SwitchProps = {
    id: string?,
    checked: boolean?,
    active_color: string?,
    inactive_color: string?,
    thumb_color: string?,
    on_toggle: ((checked: boolean) -> ())?,
}

export type VirtualListProps = {
    id: string?,
    items: { any },
    item_height: number,
    visible_height: number,
    scroll_offset: number?,
    render_item: (item: any, index: number) -> any,
}

export type ThemeTokens = {
    background: string,
    surface: string,
    surface_variant: string,
    primary: string,
    primary_container: string,
    secondary: string,
    text: string,
    text_muted: string,
    error: string,
    border: string,
}

export type Signal<T> = {
    get: () -> T,
    set: (newValue: T) -> (),
}

export type ProcessResult = {
    stdout: string,
    stderr: string,
    code: number,
}

export type Promise<T> = {
    andThen: <U>(self: Promise<T>, onFulfilled: ((value: T) -> U)?, onRejected: ((error: any) -> U)?) -> Promise<U>,
    catch: <U>(self: Promise<T>, onRejected: (error: any) -> U) -> Promise<U>,
    finally: (self: Promise<T>, onFinally: () -> ()) -> Promise<T>,
}

declare class ZenithStatic {
    Box: (props: BoxProps) -> any
    Text: (props: TextProps) -> any
    Image: (props: ImageProps) -> any
    TextInput: (props: TextInputProps) -> any
    Shader: (props: ShaderProps) -> any
    Slider: (props: SliderProps) -> any
    Switch: (props: SwitchProps) -> any
    VirtualList: (props: VirtualListProps) -> any
    
    Theme: () -> ThemeTokens
    Spring: (from: number, to: number, stiffness: number?, damping: number?) -> any
    hex: (color: string, alpha: number?) -> any
    import: (modulePath: string) -> any
    
    signal: <T>(initial: T) -> (Signal<T>, (newValue: T) -> ())
    effect: (callback: () -> ()) -> ()
    
    Promise: {
        new: <T>(executor: (resolve: (value: T) -> (), reject: (error: any) -> ()) -> ()) -> Promise<T>,
        resolve: <T>(value: T) -> Promise<T>,
        reject: <T>(error: any) -> Promise<T>,
        all: <T>(promises: { Promise<T> }) -> Promise<{ T }>,
    }
    Storage: {
        get: (key: string, defaultValue: any?) -> any,
        set: (key: string, value: any) -> (),
        has: (key: string) -> boolean,
        remove: (key: string) -> (),
        delete: (key: string) -> (),
        clear: () -> (),
        all: () -> { [string]: any },
    },
    spawn: (command: string, args: { string }?) -> Promise<ProcessResult>
    delay: (ms: number) -> Promise<nil>
    exec: (command: string, args: { string }?) -> Promise<ProcessResult>
    dispatch: (dispatcher: string, argument: string | number) -> ()
    
    Services: {
        Workspaces: () -> { active: number, workspaces: { { id: number, name: string, active: boolean, urgent: boolean, windows: number } } },
        ActiveWindow: () -> { title: string, class: string, address: string },
        Network: () -> { connected: boolean, ssid: string?, strength: number?, ethernet: boolean },
        Audio: () -> { volume: number, muted: boolean, default_sink: string },
        SetVolume: (percent: number) -> (),
        ToggleMute: () -> (),
        AudioSinks: () -> { { id: number, name: string, is_default: boolean } },
        SetAudioSink: (id: number) -> (),
        Bluetooth: () -> { powered: boolean, connected: boolean, device_name: string? },
        Battery: () -> { percentage: number, charging: boolean, time_remaining: string? },
        Media: () -> { playing: boolean, title: string, artist: string, album_art: string? },
        Timer: {
            every: (intervalMs: number, callback: () -> ()) -> (),
            after: (delayMs: number, callback: () -> ()) -> (),
        }
    }
}

return {}
