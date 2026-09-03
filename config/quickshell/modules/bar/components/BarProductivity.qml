import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../core"
import "../../../shared"
import "../../../services"

PillWidget {
    id: root

    required property color accentColor
    required property color textColor
    required property var popupInstance
    property int openTabIndex: 0
    property bool forceVisible: true
    
    // Use the singleton service instead of the popup instance for data
    // This allows the bar to work even if the popup is not loaded
    readonly property bool pomodoroRunning: ProductivityService.pomodoroRunning
    readonly property real timerRemaining: ProductivityService.timerRemaining
    readonly property bool isBreak: ProductivityService.pomodoroIsBreak
    readonly property string taskName: ProductivityService.focusedTaskText
    readonly property int pendingCount: ProductivityService.pendingTodoCount
    readonly property int completedCount: ProductivityService.completedTodoCount
    readonly property int pomodoroCount: ProductivityService.pomodoroSessionCount
    readonly property int priorityCount: ProductivityService.priorityCount

    function formatTimerTime(secs) {
        var h = Math.floor(secs / 3600);
        var m = Math.floor((secs % 3600) / 60);
        var s = Math.floor(secs % 60);
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    visible: forceVisible || root.pomodoroRunning || root.pendingCount > 0 || root.priorityCount > 0 || root.pomodoroCount > 0
    
    iconText: root.pomodoroRunning ? "\u{f017}" : (root.pendingCount > 0 ? "\u{f0ae}" : (root.priorityCount > 0 ? "\u{f005}" : "\u{f0ae}"))
    iconColor: root.pomodoroRunning ? (root.isBreak ? ColorScheme.green : ColorScheme.red) : (root.pendingCount > 0 ? ColorScheme.accent : (root.priorityCount > 0 ? "#f1c40f" : root.accentColor))
    iconFontFamily: "JetBrainsMono Nerd Font"
    
    labelText: {
        if (root.pomodoroRunning) {
            return formatTimerTime(root.timerRemaining) + (root.taskName !== "" ? " • " + root.taskName : "");
        }
        if (root.pendingCount > 0) return root.pendingCount.toString();
        if (root.priorityCount > 0) return root.priorityCount.toString();
        return root.pomodoroCount > 0 ? root.pomodoroCount.toString() : "";
    }
    
    labelColor: root.pomodoroRunning ? (root.isBreak ? ColorScheme.green : ColorScheme.red) : root.textColor
    
    checked: ShellController.isPopupOpen(root.popupInstance)
    popupOpen: checked

    tooltipText: {
        if (root.pomodoroRunning) {
            return (root.isBreak ? "Intervalo: " : "Focando em: ") + (root.taskName || "Sem tarefa");
        }
        if (root.pendingCount > 0) return root.pendingCount + " tarefas pendentes";
        if (root.priorityCount > 0) return root.priorityCount + " tarefas prioritárias para hoje";
        if (root.pomodoroCount > 0) return root.pomodoroCount + " sessões de foco hoje";
        return "Produtividade / Tarefas";
    }
    
    onClicked: {
        var isOpen = ShellController.isPopupOpen(root.popupInstance);
        if (!isOpen && root.popupInstance && root.openTabIndex >= 0 && root.popupInstance.pendingOpenOptions !== undefined)
            root.popupInstance.pendingOpenOptions = { activeTab: root.openTabIndex };

        if (isOpen && root.popupInstance && root.popupInstance.item && root.popupInstance.item.activeTab !== undefined && root.popupInstance.item.activeTab !== root.openTabIndex) {
            root.popupInstance.item.activeTab = root.openTabIndex;
            return;
        }

        ShellController.togglePopup(root, root.popupInstance);
    }
}
