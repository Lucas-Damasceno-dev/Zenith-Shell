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
    x: number?,
    y: number?,
}

export type ShadowSpec = {
    color: string,
    blur: number,
    offset_x: number?,
    offset_y: number?,
    spread: number?,
}

export type AutoHideMode = "none" | "hover" | "overlap" | "always"

export type AutoHideConfig = {
    mode: AutoHideMode,
    reveal_delay_ms: number?,
    hide_delay_ms: number?,
    peek_size: number?,
    sensor_thickness: number?,
    on_visibility_change: ((visible: boolean) -> ())?,
}

export type WindowLayer = "background" | "bottom" | "top" | "overlay"

export type LayerShellAnchor = {
    top: boolean?,
    bottom: boolean?,
    left: boolean?,
    right: boolean?,
}

export type WindowProps = {
    id: string?,
    layer: WindowLayer?,
    exclusive_zone: number?,
    anchor: LayerShellAnchor?,
    margin: PaddingSpec?,
    margins: PaddingSpec?,
    auto_hide: AutoHideConfig?,
    keyboard_interactivity: ("none" | "exclusive" | "on_demand")?,
    children: { any }?,
}

export type SpringSpec = {
    stiffness: number,
    damping: number,
    mass: number?,
    precision: number?,
}

export type PointerEvent = {
    x: number,
    y: number,
    relative_x: number,
    relative_y: number,
    button: ("left" | "right" | "middle" | "none")?,
    timestamp: number,
}

export type MagnificationSpec = {
    scale_max: number,
    radius: number,
    spring: SpringSpec?,
    on_scale_change: ((scale: number) -> ())?,
}

export type BoxProps = {
    id: string?,
    width: (number | string)?,
    height: (number | string)?,
    direction: FlexDirection?,
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
    scale: (number | any)?,
    cursor: CursorType?,
    magnification: MagnificationSpec?,
    auto_hide: AutoHideConfig?,
    on_click: (() -> ())?,
    on_right_click: (() -> ())?,
    on_pointer_enter: ((event: PointerEvent?) -> ())?,
    on_pointer_leave: ((event: PointerEvent?) -> ())?,
    on_pointer_move: ((event: PointerEvent) -> ())?,
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
    vertex: string?,
    width: (number | string)?,
    height: (number | string)?,
    uniforms: { [string]: (number | { number }) }?,
    textures: { [string]: string }?,
    border_radius: number?,
    opacity: number?,
    sdf_primitive: ("rounded_box" | "circle" | "drop_shadow" | "frosted_glass")?,
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
    surface_variant: string?,
    surface_container: string?,
    surface_container_high: string?,
    surface_container_highest: string?,
    surface_container_low: string?,
    primary: string,
    primary_container: string?,
    secondary: string?,
    tertiary: string?,
    on_surface: string?,
    on_surface_variant: string?,
    on_primary: string?,
    on_secondary: string?,
    on_tertiary: string?,
    text: string?,
    text_muted: string?,
    error: string,
    border: string?,
    outline: string?,
    outline_variant: string?,
    base00: string?,
    base01: string?,
    base02: string?,
    base03: string?,
    base04: string?,
    base05: string?,
    base06: string?,
    base07: string?,
    base08: string?,
    base09: string?,
    base0a: string?,
    base0b: string?,
    base0c: string?,
    base0d: string?,
    base0e: string?,
    base0f: string?,
    red: string?,
    peach: string?,
    yellow: string?,
    green: string?,
    teal: string?,
    blue: string?,
    mauve: string?,
    lavender: string?,
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

export type TrayItem = {
    id: string,
    title: string,
    icon: string,
    icon_name: string?,
    service: string,
    action: string?,
    context_action: string?,
    secondary_action: string?,
}

export type BrightnessSnapshot = {
    percent: number,
    current: number,
    max: number,
    device: string,
}

export type IdleState = {
    is_idle: boolean,
    idle: boolean,
}

export type Promise<T> = {
    andThen: <U>(self: Promise<T>, onFulfilled: ((value: T) -> U)?, onRejected: ((error: any) -> U)?) -> Promise<U>,
    catch: <U>(self: Promise<T>, onRejected: (error: any) -> U) -> Promise<U>,
    finally: (self: Promise<T>, onFinally: () -> ()) -> Promise<T>,
}

export type ToplevelState = {
    active: boolean,
    minimized: boolean,
    maximized: boolean,
    fullscreen: boolean,
}

export type ToplevelHandle = {
    id: string,
    title: string,
    app_id: string,
    workspace: number?,
    state: ToplevelState,
    thumbnail_uri: string?,
    thumbnail_texture_id: number?,
}

export type CanvasWidget = {
    id: string,
    x: number,
    y: number,
    width: number,
    height: number,
    pinned: boolean?,
    render: () -> any,
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
    Window: (props: WindowProps) -> any
    CanvasWidget: (props: CanvasWidget) -> any
    
    Theme: () -> ThemeTokens
    Spring: (from: number, to: number, stiffness: number?, damping: number?) -> any
    hex: (color: string, alpha: number?) -> any
    import: (modulePath: string) -> any
    
    signal: <T>(initial: T) -> (Signal<T>, (newValue: T) -> ())
    Signal: <T>(initial: T) -> Signal<T>
    effect: (callback: () -> ()) -> ()
    Effect: (callback: () -> ()) -> ()
    batch: (callback: () -> ()) -> ()
    Batch: (callback: () -> ()) -> ()
    
    Signals: {
        Time: () -> string,
        Date: () -> string,
        Cpu: () -> string,
        Memory: () -> string,
        ActiveWindow: () -> string,
        Brightness: () -> string,
        Idle: () -> boolean,
        IsIdle: () -> boolean,
        is_idle: () -> boolean,
        idle: () -> boolean,
        time: () -> string,
        date: () -> string,
        cpu: () -> string,
        memory: () -> string,
        active_window: () -> string,
        brightness: () -> string,
    }
    
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
    set_brightness: (percent: number) -> ()
    set_idle: (idle: boolean) -> ()
    get_search_query: () -> string
    set_search_query: (query: string) -> ()
    get_selected_index: () -> number
    set_selected_index: (index: number) -> ()
    lock_pass_len: () -> number
    get_lock_password_len: () -> number
    lock_pass_display: () -> string
    is_locked_out: () -> boolean
    lockout_remaining_secs: () -> number
    close: () -> ()
    reload_popup: (id: string?) -> ()
    
    Services: {
        -- System Tray (StatusNotifierItem)
        Tray: () -> { TrayItem },
        tray: () -> { TrayItem },
        TrayActivate: (service: string) -> (),
        tray_activate: (service: string) -> (),
        TrayContextMenu: (service: string) -> (),
        tray_context_menu: (service: string) -> (),
        TraySecondaryActivate: (service: string) -> (),
        tray_secondary_activate: (service: string) -> (),
        TrayScroll: (service: string, delta: number, orientation: string?) -> (),
        tray_scroll: (service: string, delta: number, orientation: string?) -> (),

        -- Display Brightness (Sysfs Backlight)
        Brightness: () -> BrightnessSnapshot,
        brightness: () -> BrightnessSnapshot,
        SetBrightness: (percent: number) -> (),
        set_brightness: (percent: number) -> (),
        InvalidateBrightnessCache: () -> (),
        invalidate_brightness_cache: () -> (),
        RefreshBrightness: () -> (),
        refresh_brightness: () -> (),
        StepBrightness: (delta: number) -> number,
        step_brightness: (delta: number) -> number,
        AdjustBrightness: (delta: number) -> number,
        adjust_brightness: (delta: number) -> number,

        -- Idle State
        Idle: () -> IdleState,
        idle: () -> IdleState,
        IsIdle: () -> boolean,
        is_idle: () -> boolean,
        SetIdle: (idle: boolean) -> (),
        set_idle: (idle: boolean) -> (),

        -- Workspaces & Windows
        Workspaces: () -> { active: number, workspaces: { { id: number, name: string, active: boolean, urgent: boolean, windows: number } } },
        workspaces: () -> { active: number, workspaces: { { id: number, name: string, active: boolean, urgent: boolean, windows: number } } },
        ActiveWindow: () -> { title: string, class: string, address: string },
        active_window: () -> { title: string, class: string, address: string },
        Clients: () -> { { address: string, title: string, class: string, workspace: number, focused: boolean } },
        clients: () -> { { address: string, title: string, class: string, workspace: number, focused: boolean } },
        FocusWindow: (address: string) -> (),
        focus_window: (address: string) -> (),
        HyprlandGaps: () -> { inner: number, outer: number, gaps_in: number?, gaps_out: number? },
        hyprland_gaps: () -> { inner: number, outer: number, gaps_in: number?, gaps_out: number? },

        -- Wayland Foreign Toplevel Management (zwlr_foreign_toplevel_management_v1)
        Toplevels: () -> { ToplevelHandle },
        toplevels: () -> { ToplevelHandle },
        ToplevelActivate: (id: string) -> (),
        toplevel_activate: (id: string) -> (),
        ToplevelClose: (id: string) -> (),
        toplevel_close: (id: string) -> (),
        ToplevelSetMinimized: (id: string, minimized: boolean) -> (),
        toplevel_set_minimized: (id: string, minimized: boolean) -> (),
        ToplevelSetMaximized: (id: string, maximized: boolean) -> (),
        toplevel_set_maximized: (id: string, maximized: boolean) -> (),

        -- Network & Connectivity
        Network: () -> { connected: boolean, ssid: string?, strength: number?, ethernet: boolean },
        network: () -> { connected: boolean, ssid: string?, strength: number?, ethernet: boolean },
        WifiScan: () -> { { ssid: string, strength: number, security: string } },
        wifi_scan: () -> { { ssid: string, strength: number, security: string } },
        SetWifiEnabled: (enabled: boolean) -> (),
        set_wifi_enabled: (enabled: boolean) -> (),
        Bluetooth: () -> { powered: boolean, connected: boolean, device_name: string? },
        bluetooth: () -> { powered: boolean, connected: boolean, device_name: string? },

        -- Audio & Media
        Audio: () -> { volume: number, muted: boolean, default_sink: string },
        audio: () -> { volume: number, muted: boolean, default_sink: string },
        SetVolume: (percent: number) -> (),
        set_volume: (percent: number) -> (),
        ToggleMute: () -> (),
        toggle_mute: () -> (),
        AudioSinks: () -> { { id: number, name: string, is_default: boolean } },
        audio_sinks: () -> { { id: number, name: string, is_default: boolean } },
        SetAudioSink: (id: number) -> (),
        set_audio_sink: (id: number) -> (),
        Spectrum: (bars: number?) -> { number },
        spectrum: (bars: number?) -> { number },
        Media: () -> { playing: boolean, title: string, artist: string, album_art: string?, is_available: boolean?, player_name: string?, status: string?, album: string?, length: number? },
        media: () -> { playing: boolean, title: string, artist: string, album_art: string?, is_available: boolean?, player_name: string?, status: string?, album: string?, length: number? },
        MediaControl: (action: string) -> (),
        media_control: (action: string) -> (),

        -- Hardware & Battery
        Battery: () -> { percentage: number, charging: boolean, time_remaining: string? },
        battery: () -> { percentage: number, charging: boolean, time_remaining: string? },
        Cpu: () -> { usage_percent: number, cores: number, model: string },
        cpu: () -> { usage_percent: number, cores: number, model: string },
        Memory: () -> { total_mb: number, used_mb: number, free_mb: number, percent: number },
        memory: () -> { total_mb: number, used_mb: number, free_mb: number, percent: number },
        Disk: () -> { total_gb: number, used_gb: number, free_gb: number, percent: number },
        disk: () -> { total_gb: number, used_gb: number, free_gb: number, percent: number },

        -- Screen & Outputs
        Screen: () -> { width: number, height: number, scale: number },
        screen: () -> { width: number, height: number, scale: number },
        Outputs: () -> { { name: string, width: number, height: number, refresh_rate: number, focused: boolean } },
        outputs: () -> { { name: string, width: number, height: number, refresh_rate: number, focused: boolean } },

        -- Notifications
        Notifications: () -> { { id: number, app_name: string, summary: string, body: string, urgency: number } },
        notifications: () -> { { id: number, app_name: string, summary: string, body: string, urgency: number } },
        NotificationClose: (id: number) -> (),
        notification_close: (id: number) -> (),
        NotificationClear: () -> (),
        notification_clear: () -> (),
        NotificationHistory: () -> { { id: number, app_name: string, summary: string, body: string, urgency: number, time: string } },
        notification_history: () -> { { id: number, app_name: string, summary: string, body: string, urgency: number, time: string } },
        IsDND: () -> boolean,
        is_dnd: () -> boolean,
        ToggleDND: () -> boolean,
        toggle_dnd: () -> boolean,
        ClearNotificationHistory: () -> (),
        clear_notification_history: () -> (),

        -- Launcher & Execution
        Launcher: (query: string, limit: number?) -> { { name: string, exec: string, icon: string, description: string, score: number } },
        launcher: (query: string, limit: number?) -> { { name: string, exec: string, icon: string, description: string, score: number } },
        Launch: (exec: string) -> (),
        launch: (exec: string) -> (),

        -- Power Management
        PowerProfile: () -> string,
        power_profile: () -> string,
        SetPowerProfile: (profile: string) -> (),
        set_power_profile: (profile: string) -> (),
        Suspend: () -> (),
        suspend: () -> (),
        Reboot: () -> (),
        reboot: () -> (),
        PowerOff: () -> (),
        power_off: () -> (),

        -- Date & Time & Weather
        time: () -> (string, string),
        date: () -> { year: number, month: number, day: number, weekday: number },
        Weather: () -> { temp: number, condition: string, icon: string, city: string },
        weather: () -> { temp: number, condition: string, icon: string, city: string },

        -- Recording & Graphics
        IsRecording: () -> boolean,
        is_recording: () -> boolean,
        ToggleRecording: () -> (),
        toggle_recording: () -> (),
        RenderSvg: (svg: string, width: number, height: number) -> string,
        render_svg: (svg: string, width: number, height: number) -> string,
        RenderSvgFile: (path: string, width: number, height: number) -> string,
        render_svg_file: (path: string, width: number, height: number) -> string,

        -- Timer
        Timer: {
            every: (intervalMs: number, callback: () -> ()) -> (),
            after: (delayMs: number, callback: () -> ()) -> (),
        }
    }
}

return {}
