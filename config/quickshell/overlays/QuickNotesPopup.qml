import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../shared"
import "../services"

/**
 * QuickNotesPopup - Popup for managing quick notes
 * Supports scrolling, editing, reordering, and copying
 */
PopupWindow {
    id: root

    property color accentColor: ColorScheme.accent
    property color textColor: ColorScheme.text
    property real popupMargin: DesignTokens.spacingLG

    // Editing state
    property string editingNoteId: ""
    property string editingText: ""

    // Drag state for reordering
    property int dragFromIndex: -1
    property int dragToIndex: -1

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    showScrim: false
    glassRadius: 0
    glassBackground: "transparent"
    glassBorderWidth: 0
    shadowBlur: 0
    originY: 0.0
    originX: 1.0
    slideY: 12

    onIsOpenChanged: {
        if (isOpen) {
            newNoteInput.text = "";
            editingNoteId = "";
            dragFromIndex = -1;
            dragToIndex = -1;
            selectedColor = "default";
            newNoteInput.forceActiveFocus();
        }
    }

    property string selectedColor: "default"

    readonly property var noteColors: [
        { id: "default", color: ColorScheme.glassCard },
        { id: "red", color: "#e74c3c" },
        { id: "orange", color: "#e67e22" },
        { id: "yellow", color: "#f1c40f" },
        { id: "green", color: "#2ecc71" },
        { id: "blue", color: "#3498db" },
        { id: "purple", color: "#9b59b6" }
    ]

    function getNoteColor(colorId) {
        for (var i = 0; i < noteColors.length; i++) {
            if (noteColors[i].id === colorId) return noteColors[i].color;
        }
        return ColorScheme.glassCard;
    }

    function copyToClipboard(text) {
        copyProc.exec(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "--", text]);
    }

    function startEditing(noteId, noteText) {
        editingNoteId = noteId;
        editingText = noteText;
    }

    function saveEditing() {
        if (editingNoteId && editingText.trim()) {
            QuickNotesService.updateNote(editingNoteId, editingText.trim());
        }
        editingNoteId = "";
        editingText = "";
    }

    function cancelEditing() {
        editingNoteId = "";
        editingText = "";
    }

    TimedProcess {
        id: copyProc
        timeoutMs: 2000
        timeoutLabel: "CopyNote"
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) {
                root.isOpen = false;
            }
        }
    }

    Item {
        id: popupCard
        width: 360
        height: Math.min(550, 220 + notesList.contentHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: popupTopMargin
        anchors.rightMargin: root.popupMargin
        z: 1

        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: 16
            color: ColorScheme.glassPopup
            border.width: 1
            border.color: ColorScheme.outlineVariant
        }

        // Lightweight drop shadow
        Rectangle {
            anchors.fill: popupBg
            anchors.topMargin: 6
            radius: popupBg.radius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\u{f249}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: root.accentColor
                    }

                    Text {
                        text: "Notas Rápidas"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Inter"
                        color: root.textColor
                        Layout.fillWidth: true
                    }

                    Text {
                        text: QuickNotesService.noteCount.toString()
                        font.pixelSize: 11
                        font.family: "Inter"
                        color: root.textColor
                        opacity: 0.6
                        visible: QuickNotesService.noteCount > 0
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: closeMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.text, 0.12) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u{f00d}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: ColorScheme.withAlpha(root.textColor, 0.7)
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.isOpen = false
                        }
                    }
                }

                // New note input
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 8
                        color: ColorScheme.glassHover
                        border.width: newNoteInput.activeFocus ? 2 : 0
                        border.color: root.accentColor

                        TextInput {
                            id: newNoteInput
                            anchors.fill: parent
                            anchors.margins: 10
                            font.pixelSize: 12
                            font.family: "Inter"
                            color: root.textColor
                            clip: true
                            
                            property string placeholderText: "Nova nota..."
                            
                            Text {
                                anchors.fill: parent
                                text: parent.placeholderText
                                font: parent.font
                                color: root.textColor
                                opacity: 0.4
                                visible: !parent.text && !parent.activeFocus
                            }

                            onAccepted: {
                                if (text.trim()) {
                                    QuickNotesService.addNote(text, root.selectedColor);
                                    text = "";
                                }
                            }

                            Keys.onEscapePressed: root.isOpen = false
                        }
                    }

                    // Color picker
                    Row {
                        spacing: 4
                        Repeater {
                            model: root.noteColors
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: modelData.color
                                border.width: root.selectedColor === modelData.id ? 2 : 0
                                border.color: root.textColor
                                opacity: colorMa.containsMouse ? 1.0 : 0.7

                                MouseArea {
                                    id: colorMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedColor = modelData.id
                                }
                            }
                        }
                    }
                }

                // Notes list with scrollbar
                ScrollView {
                    id: notesScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ScrollBar.vertical: ScrollBar {
                        policy: notesList.contentHeight > notesScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                        
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: ColorScheme.withAlpha(root.accentColor, parent.pressed ? 0.6 : (parent.hovered ? 0.4 : 0.25))
                        }
                        
                        background: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.05)
                        }
                    }

                    ListView {
                        id: notesList
                        width: notesScroll.width - 12
                        spacing: 8
                        model: QuickNotesService.notes
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: noteCard
                            required property var modelData
                            required property int index
                            
                            width: notesList.width
                            height: root.editingNoteId === modelData.id 
                                ? editArea.implicitHeight + 20
                                : noteContent.implicitHeight + 20
                            radius: 8
                            color: root.getNoteColor(modelData.color)
                            opacity: noteMa.containsMouse ? 1.0 : 0.9
                            
                            // Drag indicator
                            Rectangle {
                                width: 4
                                height: parent.height - 16
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 2
                                color: ColorScheme.withAlpha(root.textColor, dragMa.pressed ? 0.5 : (dragMa.containsMouse ? 0.3 : 0.1))
                                visible: QuickNotesService.noteCount > 1
                                
                                    MouseArea {
                                        id: dragMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.SizeVerCursor
                                        drag.target: noteCard
                                        drag.axis: Drag.YAxis

                                        onPressed: {
                                            root.dragFromIndex = index;
                                            root.dragToIndex = index;
                                        }

                                        onPositionChanged: {
                                            var targetIndex = notesList.indexAt(noteCard.x + noteCard.width / 2, noteCard.y + noteCard.height / 2);
                                            if (targetIndex >= 0)
                                                root.dragToIndex = targetIndex;
                                        }

                                        onReleased: {
                                            if (root.dragFromIndex !== -1 && root.dragToIndex !== -1 && root.dragFromIndex !== root.dragToIndex) {
                                                QuickNotesService.moveNote(root.dragFromIndex, root.dragToIndex);
                                            }
                                            root.dragFromIndex = -1;
                                            root.dragToIndex = -1;
                                            noteCard.y = noteCard.y; // Reset position
                                        }
                                }
                            }

                            MouseArea {
                                id: noteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.leftMargin: QuickNotesService.noteCount > 1 ? 16 : 10
                                spacing: 8

                                // Display mode
                                Text {
                                    id: noteContent
                                    visible: root.editingNoteId !== modelData.id
                                    text: modelData.text
                                    font.pixelSize: 12
                                    font.family: "Inter"
                                    color: root.textColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onDoubleClicked: root.startEditing(modelData.id, modelData.text)
                                    }
                                }
                                
                                // Edit mode
                                ColumnLayout {
                                    id: editArea
                                    visible: root.editingNoteId === modelData.id
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    TextArea {
                                        id: editInput
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 60
                                        Layout.maximumHeight: 150
                                        text: root.editingText
                                        font.pixelSize: 12
                                        font.family: "Inter"
                                        color: root.textColor
                                        wrapMode: Text.WordWrap
                                        background: Rectangle {
                                            color: ColorScheme.withAlpha(ColorScheme.background, 0.3)
                                            radius: 4
                                            border.width: 1
                                            border.color: root.accentColor
                                        }
                                        
                                        onTextChanged: root.editingText = text
                                        
                                        onVisibleChanged: if (visible) forceActiveFocus()
                                        
                                        Keys.onEscapePressed: root.cancelEditing()
                                    }
                                    
                                    RowLayout {
                                        spacing: 8
                                        
                                        Rectangle {
                                            width: saveEditText.width + 16
                                            height: 24
                                            radius: 12
                                            color: saveEditMa.containsMouse ? root.accentColor : ColorScheme.withAlpha(root.accentColor, 0.3)
                                            
                                            Text {
                                                id: saveEditText
                                                anchors.centerIn: parent
                                                text: "Salvar"
                                                font.pixelSize: 10
                                                font.family: "Inter"
                                                color: saveEditMa.containsMouse ? ColorScheme.background : root.textColor
                                            }
                                            
                                            MouseArea {
                                                id: saveEditMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.saveEditing()
                                            }
                                        }
                                        
                                        Text {
                                            text: "Cancelar"
                                            font.pixelSize: 10
                                            font.family: "Inter"
                                            color: root.textColor
                                            opacity: cancelEditMa.containsMouse ? 1.0 : 0.6
                                            
                                            MouseArea {
                                                id: cancelEditMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.cancelEditing()
                                            }
                                        }
                                    }
                                }

                                // Action buttons (hidden in edit mode)
                                ColumnLayout {
                                    visible: root.editingNoteId !== modelData.id
                                    spacing: 4
                                    Layout.alignment: Qt.AlignTop

                                    // Pin button
                                    Text {
                                        text: modelData.pinned ? "\u{f08d}" : "\u{f08e}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: modelData.pinned ? root.accentColor : root.textColor
                                        opacity: pinMa.containsMouse ? 1.0 : 0.5

                                        MouseArea {
                                            id: pinMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: QuickNotesService.togglePin(modelData.id)
                                        }
                                        
                                        ToolTip.visible: pinMa.containsMouse
                                        ToolTip.text: modelData.pinned ? "Desafixar" : "Fixar"
                                        ToolTip.delay: 500
                                    }
                                    
                                    // Edit button
                                    Text {
                                        text: "\u{f044}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: root.textColor
                                        opacity: editMa.containsMouse ? 1.0 : 0.5

                                        MouseArea {
                                            id: editMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.startEditing(modelData.id, modelData.text)
                                        }
                                        
                                        ToolTip.visible: editMa.containsMouse
                                        ToolTip.text: "Editar"
                                        ToolTip.delay: 500
                                    }
                                    
                                    // Copy button
                                    Text {
                                        text: "\u{f0c5}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: root.textColor
                                        opacity: copyMa.containsMouse ? 1.0 : 0.5

                                        MouseArea {
                                            id: copyMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.copyToClipboard(modelData.text)
                                        }
                                        
                                        ToolTip.visible: copyMa.containsMouse
                                        ToolTip.text: "Copiar"
                                        ToolTip.delay: 500
                                    }

                                    // Delete button
                                    Text {
                                        text: "\u{f00d}"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: "#e74c3c"
                                        opacity: deleteMa.containsMouse ? 1.0 : 0.5

                                        MouseArea {
                                            id: deleteMa
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: QuickNotesService.removeNote(modelData.id)
                                        }
                                        
                                        ToolTip.visible: deleteMa.containsMouse
                                        ToolTip.text: "Excluir"
                                        ToolTip.delay: 500
                                    }
                                }
                            }
                        }

                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            text: "Nenhuma nota ainda\nDigite acima para criar"
                            font.pixelSize: 12
                            font.family: "Inter"
                            color: root.textColor
                            opacity: 0.5
                            horizontalAlignment: Text.AlignHCenter
                            visible: QuickNotesService.noteCount === 0
                        }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    visible: QuickNotesService.noteCount > 0

                    Text {
                        text: "Dica: clique duplo para editar"
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: root.textColor
                        opacity: 0.4
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Limpar tudo"
                        font.pixelSize: 11
                        font.family: "Inter"
                        color: "#e74c3c"
                        opacity: clearMa.containsMouse ? 1.0 : 0.6

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: QuickNotesService.clearAll()
                        }
                    }
                }
            }
        }
    }
}
