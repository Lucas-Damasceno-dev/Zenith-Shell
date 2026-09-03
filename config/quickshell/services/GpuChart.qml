import QtQuick
import Quickshell
import "../core"
Item {
    id: root
    implicitWidth: 300
    implicitHeight: 80
    
    property var history: []
    property color graphColor: ColorScheme.accent

    property bool pollActive: visible

    // Consume SystemMetricsService GPU data instead of independent polling
    Connections {
        target: SystemMetricsService
        enabled: root.pollActive
        function onGpuUsageChanged() {
            let usage = Number(SystemMetricsService.gpuUsage);
            if (!isFinite(usage)) usage = 0;
            let newHistory = root.history.slice(0);
            newHistory.push(Math.max(0, Math.min(1, usage)));
            if (newHistory.length > 40) newHistory.shift();
            root.history = newHistory;
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            
            if (root.history.length < 2) return;

            let w = width;
            let h = height;
            let step = w / 39;

            // --- Desenha o Preenchimento (Gradiente) ---
            let gradient = ctx.createLinearGradient(0, 0, 0, h);
            gradient.addColorStop(0, Qt.rgba(root.graphColor.r, root.graphColor.g, root.graphColor.b, 0.3));
            gradient.addColorStop(1, "transparent");

            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let i = 0; i < root.history.length; i++) {
                ctx.lineTo(i * step, h - (root.history[i] * h));
            }
            ctx.lineTo((root.history.length - 1) * step, h);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();

            // --- Desenha a Linha ---
            ctx.beginPath();
            ctx.lineWidth = 2;
            ctx.strokeStyle = root.graphColor;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            ctx.moveTo(0, h - (root.history[0] * h));
            for (let i = 1; i < root.history.length; i++) {
                ctx.lineTo(i * step, h - (root.history[i] * h));
            }
            ctx.stroke();
        }
    }
    
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 5
        anchors.rightMargin: 5
        text: "GPU: " + Math.round((history.length > 0 ? history[history.length-1] : 0) * 100) + "%"
        color: ColorScheme.text
        font.pixelSize: 10
        font.bold: true
    }
}
