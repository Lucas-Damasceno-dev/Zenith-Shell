pragma Singleton
import QtQuick

QtObject {
    id: root

    property bool active: false
    property int tickStamp: 0

    property Timer tickTimer: Timer {
        interval: FeatureFlags.lowPowerUiMode ? 10000 : 5000
        repeat: true
        running: root.active
        onTriggered: root.tickStamp++
    }
}
