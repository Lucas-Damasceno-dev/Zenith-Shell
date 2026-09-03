pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root

    visible: false

    property string cacheIcon: ""
    property string cacheTemp: ""
    property string cacheStateText: ""
    readonly property string cachePath: RuntimePaths.stateFile("weather-cache.json")

    function cacheText(value) {
        if (value === undefined || value === null)
            return "";
        if (Array.isArray(value))
            return value.join("");
        var text = String(value);
        if (text.indexOf(",") >= 0) {
            var parts = text.split(",");
            var joined = "";
            var looksLikeChars = parts.length > 1;
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].length !== 1) {
                    looksLikeChars = false;
                    break;
                }
                joined += parts[i];
            }
            if (looksLikeChars)
                return joined;
        }
        return text;
    }

    FileView {
        id: weatherCacheFile
        path: root.cachePath
        preload: true
        printErrors: false

        JsonAdapter {
            id: cacheAdapter
            property var weatherIcon: ""
            property var temperatureText: ""
            property var cacheStateText: ""

            onWeatherIconChanged: root.cacheIcon = root.cacheText(weatherIcon)
            onTemperatureTextChanged: root.cacheTemp = root.cacheText(temperatureText)
            onCacheStateTextChanged: root.cacheStateText = root.cacheText(cacheStateText)
        }
    }

    function refreshCache() {
        weatherCacheFile.reload();
    }

    Connections {
        target: EventBus.weather

        function onCacheUpdated(payload) {
            root.refreshCache();
        }
    }
}
