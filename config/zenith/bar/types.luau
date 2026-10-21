--!strict
-- Zenith Desktop Shell — Bar Types & Static Contracts

export type BarPosition = "Top Edge" | "Bottom Edge" | "top" | "bottom"
export type BarCornerStyle = "Floating Glass" | "Edge Attached" | "Island Pill"

export type BarProps = {
    height: number?,
    compact: boolean?,
    zen_mode: boolean?,
    position: BarPosition?,
    monitor: string?,
}

export type ClusterProps = {
    compact: boolean?,
    zen_mode: boolean?,
    height: number?,
}

return {}
