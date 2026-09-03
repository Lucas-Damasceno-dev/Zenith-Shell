import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../shared"
CircularGauge {
    id: root
    iconName: "gpu"
    iconGlyph: "\u{f108}"
    
    property color accent: ColorScheme.accent
    activeColor: accent
    usage: SystemMetricsService.gpuUsage
}
