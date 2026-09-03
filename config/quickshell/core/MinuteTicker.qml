pragma Singleton
import QtQuick

QtObject {
    id: root

    property int minuteStamp: 0
    property Timer minuteTimer: Timer {
        repeat: false
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.minuteStamp++;
            root._scheduleNextTick();
        }
    }

    function _scheduleNextTick() {
        var now = new Date();
        minuteTimer.interval = Math.max(200, (60 - now.getSeconds()) * 1000 - now.getMilliseconds() + 50);
        minuteTimer.restart();
    }
}
