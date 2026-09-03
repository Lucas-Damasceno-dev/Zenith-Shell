import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import "../core"

PopupWindow {
    id: root

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
    originX: 0.5
    slideY: 10

    property real anchorX: -1
    property real popupMargin: DesignTokens.spacingLG
    property bool outsideCloseEnabled: false

    property string locationText: "Weather"
    property string temperatureText: "--°"
    property string weatherIcon: "⛅\uFE0E"
    property string weatherDescription: "No data"
    property string humidityText: "--%"
    property string feelsLikeText: "--°"
    property string windText: "-- km/h"
    property string rainText: "--%"
    property string uvText: "--"
    property string pressureText: "-- hPa"
    property bool isLoading: false
    property string errorText: ""
    property string lastFailureDetail: ""
    property string lastUpdateText: "--"
    property string cacheStateText: "No cache"
    property bool offlineMode: false
    property bool geolocationPending: false
    property bool configExpanded: false
    property var pendingRetry: null
    property var activeRequestXhr: null
    property var activeRequestOnError: null
    property string activeRequestProvider: ""
    property int activeRequestAttempt: 0

    property string weatherConfigPath: RuntimePaths.appDataFile("weather-config.json")
    property string weatherCachePath: RuntimePaths.stateFile("weather-cache.json")
    property int weatherCacheMaxAgeMs: 10 * 60 * 1000
    property int requestTimeoutMs: 12000

    function requestLayoutRefresh() {
        Qt.callLater(function() {
            if (weatherLayout && weatherLayout.forceLayout) weatherLayout.forceLayout();
        });
    }

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

    onIsOpenChanged: {
        if (isOpen) {
            outsideCloseEnabled = false;
            closeEnableTimer.restart();
            root.refreshWeather();
        } else {
            outsideCloseEnabled = false;
            root.cancelActiveRequest("");
            retryTimer.stop();
            pendingRetry = null;
        }
    }

    onConfigExpandedChanged: root.requestLayoutRefresh()

    Timer {
        id: closeEnableTimer
        interval: 120; repeat: false; running: false
        onTriggered: root.outsideCloseEnabled = true
    }

    FileView {
        id: weatherConfigFile
        path: root.weatherConfigPath
        preload: true
        printErrors: false
        onLoaded: {
            root.loadSavedLocations();
            root.refreshWeather();
        }
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) weatherConfigFile.writeAdapter();
        }
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: weatherConfig
            property string mode: "city"
            property string city: "Sao Paulo"
            property string latitude: "-23.5505"
            property string longitude: "-46.6333"
            property string customName: ""
            property string unitsTemp: "C"
            property string unitsWind: "kmh"
            property string unitsPressure: "hPa"
            property string savedLocationsJson: "[]"
        }
    }

    FileView {
        id: weatherCacheFile
        path: root.weatherCachePath
        preload: true
        printErrors: false
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) weatherCacheFile.writeAdapter();
        }
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: weatherCache
            property int updatedAtMs: 0
            property string payloadJson: ""
            property string payloadLabel: ""
            property string locationText: ""
            property string temperatureText: ""
            property string weatherIcon: ""
            property string weatherDescription: ""
            property string humidityText: ""
            property string feelsLikeText: ""
            property string windText: ""
            property string rainText: ""
            property string uvText: ""
            property string pressureText: ""
            property string cacheStateText: ""
        }
    }

    ListModel { id: forecastModel }
    ListModel { id: dailyModel }
    ListModel { id: savedLocationsModel }

    // Hourly temps for the canvas chart
    property var hourlyTemps: []
    property var hourlyLabels: []

    function tempValueString(celsius) {
        if (celsius === undefined || celsius === null) return "--°";
        var c = Number(celsius);
        if (isNaN(c)) return "--°";
        if ((weatherConfig.unitsTemp || "C") === "F") {
            return Math.round((c * 9 / 5) + 32) + "°F";
        }
        return Math.round(c) + "°C";
    }

    function windValueString(kmh) {
        if (kmh === undefined || kmh === null) return "--";
        var w = Number(kmh);
        if (isNaN(w)) return "--";
        if ((weatherConfig.unitsWind || "kmh") === "mph") {
            return Math.round(w * 0.621371) + " mph";
        }
        return Math.round(w) + " km/h";
    }

    function pressureValueString(hpa) {
        if (hpa === undefined || hpa === null) return "--";
        var p = Number(hpa);
        if (isNaN(p)) return "--";
        if ((weatherConfig.unitsPressure || "hPa") === "inHg") {
            return (p * 0.0295299830714).toFixed(2) + " inHg";
        }
        return Math.round(p) + " hPa";
    }

    function loadSavedLocations() {
        savedLocationsModel.clear();
        var raw = String(weatherConfig.savedLocationsJson || "[]");
        var parsed = [];
        try { parsed = JSON.parse(raw); } catch (e) { parsed = []; }
        if (!Array.isArray(parsed)) parsed = [];
        for (var i = 0; i < parsed.length; i++) {
            var item = parsed[i];
            if (!item) continue;
            savedLocationsModel.append({
                mode: String(item.mode || "city"),
                city: String(item.city || ""),
                latitude: String(item.latitude || ""),
                longitude: String(item.longitude || ""),
                customName: String(item.customName || "")
            });
        }
    }

    function saveLocationsModel() {
        var rows = [];
        for (var i = 0; i < savedLocationsModel.count; i++) {
            var item = savedLocationsModel.get(i);
            rows.push({
                mode: String(item.mode || "city"),
                city: String(item.city || ""),
                latitude: String(item.latitude || ""),
                longitude: String(item.longitude || ""),
                customName: String(item.customName || "")
            });
        }
        weatherConfig.savedLocationsJson = JSON.stringify(rows);
        weatherConfigFile.writeAdapter();
    }

    function saveCurrentAsPreset() {
        var item = {
            mode: weatherConfig.mode || "city",
            city: weatherConfig.city || "",
            latitude: weatherConfig.latitude || "",
            longitude: weatherConfig.longitude || "",
            customName: weatherConfig.customName || ""
        };
        savedLocationsModel.insert(0, item);
        while (savedLocationsModel.count > 12) savedLocationsModel.remove(savedLocationsModel.count - 1);
        saveLocationsModel();
    }

    function applyPreset(index) {
        if (index < 0 || index >= savedLocationsModel.count) return;
        var item = savedLocationsModel.get(index);
        weatherConfig.mode = item.mode || "city";
        weatherConfig.city = item.city || "";
        weatherConfig.latitude = item.latitude || "";
        weatherConfig.longitude = item.longitude || "";
        weatherConfig.customName = item.customName || "";
        weatherConfigFile.writeAdapter();
        refreshWeather(true);
    }

    function iconForCode(code) {
        if (code === 0) return "☀";
        if (code === 1 || code === 2) return "⛅\uFE0E";
        if (code === 3) return "☁";
        if (code === 45 || code === 48) return "🌫";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "🌧";
        if (code >= 71 && code <= 77) return "❄";
        if (code >= 95) return "⛈";
        return "⛅\uFE0E";
    }

    function descriptionForCode(code) {
        if (code === 0) return "Clear sky";
        if (code === 1 || code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 67) return "Drizzle / rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Rain showers";
        if (code >= 95) return "Thunderstorm";
        return "Unknown";
    }

    function applyCachedWeather() {
        var locationText = root.cacheText(weatherCache.locationText);
        var temperatureText = root.cacheText(weatherCache.temperatureText);
        var weatherIcon = root.cacheText(weatherCache.weatherIcon);
        var weatherDescription = root.cacheText(weatherCache.weatherDescription);
        var humidityText = root.cacheText(weatherCache.humidityText);
        var feelsLikeText = root.cacheText(weatherCache.feelsLikeText);
        var windText = root.cacheText(weatherCache.windText);
        var rainText = root.cacheText(weatherCache.rainText);
        var uvText = root.cacheText(weatherCache.uvText);
        var pressureText = root.cacheText(weatherCache.pressureText);
        var cacheStateText = root.cacheText(weatherCache.cacheStateText);

        if (temperatureText === "") return false;
        root.locationText = locationText || root.locationText;
        root.temperatureText = temperatureText || root.temperatureText;
        root.weatherIcon = weatherIcon || root.weatherIcon;
        root.weatherDescription = weatherDescription || root.weatherDescription;
        root.humidityText = humidityText || root.humidityText;
        root.feelsLikeText = feelsLikeText || root.feelsLikeText;
        root.windText = windText || root.windText;
        root.rainText = rainText || root.rainText;
        root.uvText = uvText || root.uvText;
        root.pressureText = pressureText || root.pressureText;
        root.cacheStateText = cacheStateText || "Cached";
        if (weatherCache.updatedAtMs && weatherCache.updatedAtMs > 0)
            root.lastUpdateText = Qt.formatDateTime(new Date(weatherCache.updatedAtMs), "dd/MM HH:mm");
        root.offlineMode = true;
        return true;
    }

    function applyFreshCachedPayloadIfAvailable() {
        if (!weatherCache.updatedAtMs || weatherCache.updatedAtMs <= 0) return false;
        var payloadJson = root.cacheText(weatherCache.payloadJson);
        if (!payloadJson || payloadJson === "") return false;
        if ((Date.now() - weatherCache.updatedAtMs) > root.weatherCacheMaxAgeMs) return false;
        try {
            var parsed = JSON.parse(payloadJson);
            root.updateFromWeatherPayload(parsed, root.cacheText(weatherCache.payloadLabel) || root.locationText || "Weather");
            root.errorText = "";
            root.cacheStateText = "Fresh cache";
            root.lastUpdateText = Qt.formatDateTime(new Date(weatherCache.updatedAtMs), "dd/MM HH:mm");
            root.offlineMode = false;
            return true;
        } catch (e) {
            return false;
        }
    }

    function requestJson(url, onSuccess, onError, provider) {
        requestJsonWithRetry(url, onSuccess, onError, 0, provider || "weather");
    }

    function cancelActiveRequest(reason) {
        if (!activeRequestXhr) return;
        var xhr = activeRequestXhr;
        var provider = activeRequestProvider || "weather";
        var attempt = activeRequestAttempt;
        activeRequestXhr = null;
        activeRequestOnError = null;
        activeRequestProvider = "";
        activeRequestAttempt = 0;
        requestTimeoutTimer.stop();
        try { xhr.abort(); } catch (e) {}
        if (reason) {
            EventBus.weather.publishError({
                provider: provider,
                attempt: attempt + 1,
                message: "aborted: " + reason
            });
        }
    }

    function requestJsonWithRetry(url, onSuccess, onError, attempt, provider) {
        var maxAttempts = 3;
        cancelActiveRequest("");
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        activeRequestXhr = xhr;
        activeRequestOnError = onError;
        activeRequestProvider = provider || "weather";
        activeRequestAttempt = attempt;
        requestTimeoutTimer.restart();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr === activeRequestXhr) {
                activeRequestXhr = null;
                activeRequestOnError = null;
                activeRequestProvider = "";
                activeRequestAttempt = 0;
                requestTimeoutTimer.stop();
            }
            if (xhr.status >= 200 && xhr.status < 300) {
                try { onSuccess(JSON.parse(xhr.responseText)); }
                catch (e) { onError("Invalid API response"); }
            } else {
                if (attempt + 1 < maxAttempts) {
                    var nextAttempt = attempt + 1;
                    var delayMs = Math.pow(2, attempt) * 700;
                    root.pendingRetry = function() {
                        root.requestJsonWithRetry(url, onSuccess, onError, nextAttempt, provider);
                    };
                    retryTimer.interval = delayMs;
                    retryTimer.restart();
                    return;
                }
                EventBus.weather.publishError({
                    provider: provider || "weather",
                    attempt: attempt + 1,
                    message: "HTTP " + xhr.status
                });
                onError("HTTP " + xhr.status);
            }
        };
        xhr.onerror = function() {
            if (xhr === activeRequestXhr) {
                activeRequestXhr = null;
                activeRequestOnError = null;
                activeRequestProvider = "";
                activeRequestAttempt = 0;
                requestTimeoutTimer.stop();
            }
            if (attempt + 1 < maxAttempts) {
                var nextAttempt = attempt + 1;
                var delayMs = Math.pow(2, attempt) * 700;
                root.pendingRetry = function() {
                    root.requestJsonWithRetry(url, onSuccess, onError, nextAttempt, provider);
                };
                retryTimer.interval = delayMs;
                retryTimer.restart();
                return;
            }
            EventBus.weather.publishError({
                provider: provider || "weather",
                attempt: attempt + 1,
                message: "Network error"
            });
            onError("Network error");
        };
        xhr.send();
    }

    Timer {
        id: retryTimer
        interval: 700
        repeat: false
        running: false
        onTriggered: {
            if (!root.pendingRetry) return;
            var fn = root.pendingRetry;
            root.pendingRetry = null;
            fn();
        }
    }

    Timer {
        id: requestTimeoutTimer
        interval: root.requestTimeoutMs
        repeat: false
        running: false
        onTriggered: {
            if (!root.activeRequestXhr) return;
            var xhr = root.activeRequestXhr;
            var provider = root.activeRequestProvider || "weather";
            var attempt = root.activeRequestAttempt;
            var errorFn = root.activeRequestOnError;
            root.activeRequestXhr = null;
            root.activeRequestOnError = null;
            root.activeRequestProvider = "";
            root.activeRequestAttempt = 0;
            try { xhr.abort(); } catch (e) {}
            EventBus.weather.publishError({
                provider: provider,
                attempt: attempt + 1,
                message: "timeout after " + root.requestTimeoutMs + "ms"
            });
            if (errorFn) errorFn("Timeout");
        }
    }

    function updateFromWeatherPayload(payload, label) {
        var current = payload.current || {};
        var code = parseInt(current.weather_code || "-1", 10);

        root.locationText = label || "Weather";
        root.weatherIcon = root.iconForCode(code);
        root.weatherDescription = root.descriptionForCode(code);
        root.temperatureText = current.temperature_2m !== undefined ? root.tempValueString(current.temperature_2m) : "--";
        root.feelsLikeText = current.apparent_temperature !== undefined ? root.tempValueString(current.apparent_temperature) : "--";
        root.humidityText = current.relative_humidity_2m !== undefined ? Math.round(current.relative_humidity_2m) + "%" : "--%";
        root.windText = current.wind_speed_10m !== undefined ? root.windValueString(current.wind_speed_10m) : "--";
        root.pressureText = current.surface_pressure !== undefined ? root.pressureValueString(current.surface_pressure) : "--";
        root.offlineMode = false;
        root.cacheStateText = "Live";
        root.lastUpdateText = Qt.formatDateTime(new Date(), "dd/MM HH:mm");

        // Hourly forecast (next 12h for chart)
        forecastModel.clear();
        var hourly = payload.hourly || {};
        var times = hourly.time || [];
        var codeList = hourly.weather_code || [];
        var tempList = hourly.temperature_2m || [];
        var humidityList = hourly.relative_humidity_2m || [];
        var rainList = hourly.precipitation_probability || [];

        var startIndex = 0;
        if (current.time) {
            var idx = times.indexOf(current.time);
            if (idx >= 0) startIndex = idx;
        }

        var chartTemps = [];
        var chartLabels = [];

        for (var i = startIndex; i < Math.min(startIndex + 12, times.length); i++) {
            var t = times[i] || "";
            var hour = t.length >= 16 ? t.substring(11, 16) : t;
            var hCode = parseInt(codeList[i] || "0", 10);
            var tempRaw = tempList[i] !== undefined ? Number(tempList[i]) : 0;
            var temp = (weatherConfig.unitsTemp || "C") === "F"
                ? Math.round((tempRaw * 9 / 5) + 32)
                : Math.round(tempRaw);

            if (i < startIndex + 5) {
                forecastModel.append({
                    hour: hour,
                    icon: root.iconForCode(hCode),
                    temp: root.tempValueString(tempList[i]),
                    humidity: humidityList[i] !== undefined ? Math.round(humidityList[i]) + "%" : "--%",
                    rain: rainList[i] !== undefined ? Math.round(rainList[i]) + "%" : "--%"
                });
            }

            chartTemps.push(temp);
            chartLabels.push(hour);
        }

        root.hourlyTemps = chartTemps;
        root.hourlyLabels = chartLabels;
        tempChart.requestPaint();

        // Daily forecast
        dailyModel.clear();
        var daily = payload.daily || {};
        var dTimes = daily.time || [];
        var dCodeList = daily.weather_code || [];
        var dTempMax = daily.temperature_2m_max || [];
        var dTempMin = daily.temperature_2m_min || [];
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

        for (var d = 0; d < Math.min(5, dTimes.length); d++) {
            var dateObj = new Date(dTimes[d]);
            var dayLabel = d === 0 ? "Today" : dayNames[dateObj.getDay()];
            var dCode = parseInt(dCodeList[d] || "0", 10);
            dailyModel.append({
                day: dayLabel,
                icon: root.iconForCode(dCode),
                high: dTempMax[d] !== undefined ? root.tempValueString(dTempMax[d]) : "--",
                low: dTempMin[d] !== undefined ? root.tempValueString(dTempMin[d]) : "--"
            });
        }

        // UV index
        var dailyCurrent = payload.daily || {};
        var uvList = dailyCurrent.uv_index_max || [];
        root.uvText = uvList.length > 0 && uvList[0] !== undefined ? Math.round(uvList[0] * 10) / 10 + "" : "--";
        root.rainText = rainList.length > 0 && rainList[startIndex] !== undefined
            ? Math.round(rainList[startIndex]) + "%"
            : "--%";

        weatherCache.locationText = root.locationText;
        weatherCache.temperatureText = root.temperatureText;
        weatherCache.weatherIcon = root.weatherIcon;
        weatherCache.weatherDescription = root.weatherDescription;
        weatherCache.humidityText = root.humidityText;
        weatherCache.feelsLikeText = root.feelsLikeText;
        weatherCache.windText = root.windText;
        weatherCache.rainText = root.rainText;
        weatherCache.uvText = root.uvText;
        weatherCache.pressureText = root.pressureText;
        weatherCache.cacheStateText = root.cacheStateText;
        weatherCache.payloadLabel = label || "Weather";
        weatherCache.payloadJson = JSON.stringify(payload);
        weatherCache.updatedAtMs = Date.now();
        weatherCacheFile.writeAdapter();
        EventBus.weather.publishCacheUpdated({
            cacheStateText: weatherCache.cacheStateText,
            updatedAtMs: weatherCache.updatedAtMs
        });
    }

    function fetchWeatherFor(lat, lon, label) {
        var weatherUrl = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,surface_pressure"
            + "&hourly=temperature_2m,relative_humidity_2m,weather_code,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,uv_index_max"
            + "&timezone=auto&forecast_days=5";

        requestJson(weatherUrl, function(payload) {
            root.errorText = "";
            root.lastFailureDetail = "";
            root.isLoading = false;
            root.updateFromWeatherPayload(payload, label);
        }, function(errorMessage) {
            root.lastFailureDetail = "provider=open-meteo attempt=3 error=" + errorMessage;
            root.fetchFallbackWeatherByCoords(lat, lon, label, errorMessage);
        }, "open-meteo");
    }

    function updateFromWttrPayload(payload, label) {
        var current = (payload.current_condition && payload.current_condition.length > 0)
            ? payload.current_condition[0]
            : {};
        var weatherRows = payload.weather || [];
        var hourlyRows = weatherRows.length > 0 && weatherRows[0].hourly ? weatherRows[0].hourly : [];
        var now = new Date();
        var currentHour = now.getHours();

        root.locationText = label || root.locationText;
        root.weatherDescription = current.weatherDesc && current.weatherDesc.length > 0
            ? String(current.weatherDesc[0].value || "Weather")
            : "Weather";
        root.weatherIcon = root.weatherDescription.toLowerCase().indexOf("rain") >= 0 ? "🌧"
            : (root.weatherDescription.toLowerCase().indexOf("snow") >= 0 ? "❄" : "⛅");
        root.temperatureText = root.tempValueString(Number(current.temp_C || 0));
        root.feelsLikeText = root.tempValueString(Number(current.FeelsLikeC || current.temp_C || 0));
        root.humidityText = current.humidity ? String(current.humidity) + "%" : "--%";
        root.windText = root.windValueString(Number(current.windspeedKmph || 0));
        root.pressureText = root.pressure ? root.pressureValueString(Number(current.pressure)) : "--";
        root.rainText = current.precipMM ? (Math.round(Number(current.precipMM) * 10) / 10) + " mm" : "--";
        root.uvText = current.uvIndex ? String(current.uvIndex) : "--";
        root.offlineMode = false;
        root.cacheStateText = "Fallback";
        root.lastUpdateText = Qt.formatDateTime(new Date(), "dd/MM HH:mm");

        forecastModel.clear();
        root.hourlyTemps = [];
        root.hourlyLabels = [];
        var nextCount = 0;
        for (var i = 0; i < hourlyRows.length; i++) {
            var row = hourlyRows[i];
            var hourNum = Math.floor(Number(row.time || "0") / 100);
            if (isNaN(hourNum)) continue;
            if (hourNum < currentHour && nextCount === 0) continue;
            var hourLabel = (hourNum < 10 ? "0" : "") + hourNum + ":00";
            var tempC = Number(row.tempC || "0");
            var rainChance = row.chanceofrain ? String(row.chanceofrain) + "%" : "--%";
            var hum = row.humidity ? String(row.humidity) + "%" : "--%";
            var chartTemp = (weatherConfig.unitsTemp || "C") === "F"
                ? Math.round((tempC * 9 / 5) + 32)
                : Math.round(tempC);
            root.hourlyTemps.push(chartTemp);
            root.hourlyLabels.push(hourLabel);
            if (nextCount < 5) {
                forecastModel.append({
                    hour: hourLabel,
                    icon: row.weatherDesc && row.weatherDesc.length > 0
                        ? (String(row.weatherDesc[0].value || "").toLowerCase().indexOf("rain") >= 0 ? "🌧" : "⛅")
                        : "⛅",
                    temp: root.tempValueString(tempC),
                    humidity: hum,
                    rain: rainChance
                });
            }
            nextCount++;
            if (nextCount >= 12) break;
        }
        tempChart.requestPaint();

        dailyModel.clear();
        for (var d = 0; d < Math.min(5, weatherRows.length); d++) {
            var day = weatherRows[d];
            var date = new Date(day.date || "");
            var dayLabel = d === 0 ? "Today" : Qt.formatDateTime(date, "ddd");
            var desc = day.hourly && day.hourly.length > 0 && day.hourly[0].weatherDesc && day.hourly[0].weatherDesc.length > 0
                ? String(day.hourly[0].weatherDesc[0].value || "")
                : "";
            dailyModel.append({
                day: dayLabel,
                icon: desc.toLowerCase().indexOf("rain") >= 0 ? "🌧" : "⛅",
                high: root.tempValueString(Number(day.maxtempC || "0")),
                low: root.tempValueString(Number(day.mintempC || "0"))
            });
        }

        weatherCache.locationText = root.locationText;
        weatherCache.temperatureText = root.temperatureText;
        weatherCache.weatherIcon = root.weatherIcon;
        weatherCache.weatherDescription = root.weatherDescription;
        weatherCache.humidityText = root.humidityText;
        weatherCache.feelsLikeText = root.feelsLikeText;
        weatherCache.windText = root.windText;
        weatherCache.rainText = root.rainText;
        weatherCache.uvText = root.uvText;
        weatherCache.pressureText = root.pressureText;
        weatherCache.cacheStateText = root.cacheStateText;
        weatherCache.payloadLabel = label || "Weather";
        weatherCache.payloadJson = "";
        weatherCache.updatedAtMs = Date.now();
        weatherCacheFile.writeAdapter();
        EventBus.weather.publishCacheUpdated({
            cacheStateText: weatherCache.cacheStateText,
            updatedAtMs: weatherCache.updatedAtMs
        });
    }

    function fetchFallbackWeatherByCoords(lat, lon, label, openMeteoError) {
        var query = encodeURIComponent(lat + "," + lon);
        var wttrUrl = "https://wttr.in/" + query + "?format=j1";
        requestJson(wttrUrl, function(payload) {
            root.errorText = "Open-Meteo unavailable (" + openMeteoError + "), using fallback provider";
            root.lastFailureDetail = "";
            root.isLoading = false;
            root.updateFromWttrPayload(payload, label || ("Lat " + lat.toFixed(2) + ", Lon " + lon.toFixed(2)));
        }, function(fallbackError) {
            root.isLoading = false;
            root.lastFailureDetail = "provider=wttr attempt=3 error=" + fallbackError;
            if (root.applyCachedWeather()) {
                root.errorText = "Weather failed: " + openMeteoError + " / fallback: " + fallbackError + " (using cache)";
            } else {
                root.errorText = "Weather failed: " + openMeteoError + " / fallback: " + fallbackError;
            }
        }, "wttr");
    }

    function fetchFallbackWeatherByCity(cityName, openMeteoError) {
        var wttrUrl = "https://wttr.in/" + encodeURIComponent(cityName) + "?format=j1";
        requestJson(wttrUrl, function(payload) {
            root.errorText = "City lookup failed on Open-Meteo (" + openMeteoError + "), using fallback provider";
            root.lastFailureDetail = "";
            root.isLoading = false;
            var label = (weatherConfig.customName || "").trim();
            if (label === "") label = cityName;
            root.updateFromWttrPayload(payload, label);
        }, function(fallbackError) {
            root.isLoading = false;
            root.lastFailureDetail = "provider=wttr-city attempt=3 error=" + fallbackError;
            if (root.applyCachedWeather()) {
                root.errorText = "City lookup failed: " + openMeteoError + " / fallback: " + fallbackError + " (using cache)";
            } else {
                root.errorText = "City lookup failed: " + openMeteoError + " / fallback: " + fallbackError;
            }
        }, "wttr");
    }

    function resolveCityAndFetch(cityName) {
        var geocodeUrl = "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name="
            + encodeURIComponent(cityName);

        requestJson(geocodeUrl, function(payload) {
            var result = payload.results && payload.results.length > 0 ? payload.results[0] : null;
            if (!result) {
                root.isLoading = false;
                root.errorText = "City not found";
                root.lastFailureDetail = "provider=geocode error=city-not-found";
                return;
            }
            var label = (weatherConfig.customName || "").trim();
            if (label === "") label = result.name;
            fetchWeatherFor(result.latitude, result.longitude, label);
        }, function(errorMessage) {
            root.lastFailureDetail = "provider=geocode attempt=3 error=" + errorMessage;
            root.fetchFallbackWeatherByCity(cityName, errorMessage);
        }, "geocode");
    }

    function resolveAutoLocationAndFetch() {
        root.geolocationPending = true;
        requestJson("https://ipapi.co/json", function(payload) {
            root.geolocationPending = false;
            var lat = Number(payload.latitude);
            var lon = Number(payload.longitude);
            if (isNaN(lat) || isNaN(lon)) {
                root.errorText = "Auto-location failed";
                root.lastFailureDetail = "provider=ipapi error=invalid-payload";
                root.isLoading = false;
                if (root.applyCachedWeather()) root.errorText += " (using cache)";
                return;
            }
            weatherConfig.latitude = String(lat);
            weatherConfig.longitude = String(lon);
            weatherConfig.city = String(payload.city || "");
            weatherConfig.customName = String(payload.city || "");
            weatherConfigFile.writeAdapter();
            fetchWeatherFor(lat, lon, weatherConfig.customName || "Auto location");
        }, function(err) {
            root.geolocationPending = false;
            root.isLoading = false;
            root.lastFailureDetail = "provider=ipapi attempt=3 error=" + err;
            if (root.applyCachedWeather()) root.errorText = "Auto-location failed: " + err + " (using cache)";
            else root.errorText = "Auto-location failed: " + err;
        }, "ipapi");
    }

    function refreshWeather(forceNetwork) {
        if (root.activeRequestXhr !== null && forceNetwork !== true)
            return;
        if (forceNetwork !== true && root.applyFreshCachedPayloadIfAvailable()) {
            root.isLoading = false;
            return;
        }
        root.isLoading = true;
        root.errorText = "";
        root.lastFailureDetail = "";
        var mode = (weatherConfig.mode || "city");
        if (mode === "auto") {
            resolveAutoLocationAndFetch();
            return;
        }
        if (mode === "coords") {
            var lat = parseFloat(weatherConfig.latitude || "");
            var lon = parseFloat(weatherConfig.longitude || "");
            if (isNaN(lat) || isNaN(lon)) { root.isLoading = false; root.errorText = "Invalid coordinates"; return; }
            if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                root.isLoading = false;
                root.errorText = "Coordinates out of range";
                return;
            }
            var custom = (weatherConfig.customName || "").trim();
            var label = custom !== "" ? custom : ("Lat " + lat.toFixed(2) + ", Lon " + lon.toFixed(2));
            fetchWeatherFor(lat, lon, label);
            return;
        }
        var city = (weatherConfig.city || "").trim();
        if (city === "") { root.isLoading = false; root.errorText = "City is empty"; return; }
        resolveCityAndFetch(city);
    }

    function saveConfigFromForm() {
        weatherConfig.mode = modeAutoBtn.active ? "auto" : (modeCityBtn.active ? "city" : "coords");
        weatherConfig.city = cityField.text.trim();
        weatherConfig.latitude = latField.text.trim();
        weatherConfig.longitude = lonField.text.trim();
        weatherConfig.customName = customNameField.text.trim();
        weatherConfig.unitsTemp = unitTempF.active ? "F" : "C";
        weatherConfig.unitsWind = unitWindMph.active ? "mph" : "kmh";
        weatherConfig.unitsPressure = unitPressureInHg.active ? "inHg" : "hPa";
        weatherConfigFile.writeAdapter();
        refreshWeather(true);
    }

    Timer {
        interval: 900000; repeat: true; running: root.isOpen; triggeredOnStart: false
        onTriggered: root.refreshWeather(true)
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: 0
        onClicked: (mouse) => {
            var p = mapToItem(popupCard, mouse.x, mouse.y);
            if (p.x < 0 || p.y < 0 || p.x > popupCard.width || p.y > popupCard.height) root.isOpen = false;
        }
    }

    Item {
        id: popupCard
        width: 400
        height: Math.min(root.height - (anchors.topMargin + root.popupMargin), weatherLayout.implicitHeight + 46)
        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        anchors.top: parent.top
        anchors.topMargin: popupTopMargin
        x: Math.max(root.popupMargin, Math.min(root.width - width - root.popupMargin, (root.anchorX >= 0 ? root.anchorX : root.width / 2) - width / 2))
        z: 1

        Rectangle {
            id: popupBg; anchors.fill: parent; radius: 18
            color: ColorScheme.withAlpha(ColorScheme.background, 0.72)
            border.color: ColorScheme.glassBorder; border.width: 1
        }

        Rectangle {
            anchors.fill: popupBg; anchors.topMargin: 6
            radius: popupBg.radius; color: Qt.rgba(0, 0, 0, 0.15); z: -1
        }

        ColumnLayout {
            id: weatherLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: 10

                Text { text: root.weatherIcon; font.pixelSize: 28; color: ColorScheme.accent }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: root.temperatureText
                        color: ColorScheme.text; font.pixelSize: 24; font.bold: true; font.family: "Inter"
                    }
                    Text {
                        text: root.weatherDescription + " • " + root.locationText
                        color: ColorScheme.withAlpha(ColorScheme.text, 0.6)
                        font.pixelSize: 10; font.family: "Inter"; elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: refreshMa.containsMouse ? ColorScheme.glassHover : ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f2f1}"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        color: ColorScheme.accent
                    }

                    RotationAnimation on rotation {
                        running: root.isLoading; loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }

                    MouseArea {
                        id: refreshMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: root.refreshWeather(true)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    radius: 8
                    height: 20
                    width: cacheText.implicitWidth + 10
                    color: root.offlineMode
                        ? ColorScheme.withAlpha(ColorScheme.yellow, 0.22)
                        : ColorScheme.withAlpha(ColorScheme.green, 0.18)
                    Text {
                        id: cacheText
                        anchors.centerIn: parent
                        text: root.cacheStateText + (root.offlineMode ? " • offline" : "")
                        color: root.offlineMode ? ColorScheme.yellow : ColorScheme.green
                        font.pixelSize: 9
                        font.family: "Inter"
                    }
                }

                Text {
                    text: "Updated: " + root.lastUpdateText
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                    font.pixelSize: 9
                    font.family: "Inter"
                }

                Item { Layout.fillWidth: true }
            }

            // Detail cards grid
            GridLayout {
                Layout.fillWidth: true; columns: 5; rowSpacing: 6; columnSpacing: 6

                Repeater {
                    model: [
                        { label: "Feels like", value: root.feelsLikeText },
                        { label: "Humidity", value: root.humidityText },
                        { label: "Wind", value: root.windText },
                        { label: "Rain", value: root.rainText },
                        { label: "UV Index", value: root.uvText }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 48; radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.30)
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text {
                                text: modelData.label; anchors.horizontalCenter: parent.horizontalCenter
                                color: ColorScheme.withAlpha(ColorScheme.text, 0.45)
                                font.pixelSize: 8; font.family: "Inter"
                            }
                            Text {
                                text: modelData.value; anchors.horizontalCenter: parent.horizontalCenter
                                color: ColorScheme.text; font.pixelSize: 12; font.bold: true; font.family: "Inter"
                            }
                        }
                    }
                }
            }

            // Temperature chart (Canvas)
            Rectangle {
                Layout.fillWidth: true; height: 90; radius: 12
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.22)

                Canvas {
                    id: tempChart
                    anchors.fill: parent; anchors.margins: 8

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var temps = root.hourlyTemps;
                        if (!temps || temps.length < 2) return;

                        var w = width, h = height;
                        var minT = Math.min.apply(null, temps) - 2;
                        var maxT = Math.max.apply(null, temps) + 2;
                        var range = maxT - minT || 1;

                        // Draw gradient fill
                        var grad = ctx.createLinearGradient(0, 0, 0, h);
                        var accentR = ColorScheme.accent.r, accentG = ColorScheme.accent.g, accentB = ColorScheme.accent.b;
                        grad.addColorStop(0, "rgba(" + Math.round(accentR*255) + "," + Math.round(accentG*255) + "," + Math.round(accentB*255) + ",0.3)");
                        grad.addColorStop(1, "rgba(" + Math.round(accentR*255) + "," + Math.round(accentG*255) + "," + Math.round(accentB*255) + ",0.02)");

                        ctx.beginPath();
                        for (var i = 0; i < temps.length; i++) {
                            var x = (i / (temps.length - 1)) * w;
                            var y = h - ((temps[i] - minT) / range) * (h - 20) - 10;
                            if (i === 0) ctx.moveTo(x, y);
                            else ctx.lineTo(x, y);
                        }
                        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
                        ctx.fillStyle = grad; ctx.fill();

                        // Draw line
                        ctx.beginPath();
                        for (var j = 0; j < temps.length; j++) {
                            var lx = (j / (temps.length - 1)) * w;
                            var ly = h - ((temps[j] - minT) / range) * (h - 20) - 10;
                            if (j === 0) ctx.moveTo(lx, ly);
                            else ctx.lineTo(lx, ly);
                        }
                        ctx.strokeStyle = Qt.rgba(accentR, accentG, accentB, 0.8);
                        ctx.lineWidth = 2; ctx.stroke();

                        // Draw dots + labels
                        ctx.fillStyle = Qt.rgba(accentR, accentG, accentB, 1);
                        ctx.font = "9px Inter";
                        ctx.textAlign = "center";
                        for (var k = 0; k < temps.length; k++) {
                            var dx = (k / (temps.length - 1)) * w;
                            var dy = h - ((temps[k] - minT) / range) * (h - 20) - 10;
                            ctx.beginPath(); ctx.arc(dx, dy, 2.5, 0, 2 * Math.PI); ctx.fill();

                            // Show label every 2-3 points
                            if (k % 3 === 0 || k === temps.length - 1) {
                                ctx.fillStyle = Qt.rgba(ColorScheme.text.r, ColorScheme.text.g, ColorScheme.text.b, 0.5);
                                ctx.fillText(temps[k] + "°", dx, dy - 8);
                                ctx.fillStyle = Qt.rgba(accentR, accentG, accentB, 1);
                            }
                        }
                    }
                }
            }

            // Daily forecast
            RowLayout {
                Layout.fillWidth: true; spacing: 4

                Repeater {
                    model: dailyModel
                    delegate: Rectangle {
                        required property string day
                        required property string icon
                        required property string high
                        required property string low
                        Layout.fillWidth: true; height: 70; radius: 10
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.28)
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: day; anchors.horizontalCenter: parent.horizontalCenter; color: ColorScheme.withAlpha(ColorScheme.text, 0.55); font.pixelSize: 9; font.family: "Inter" }
                            Text { text: icon; anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 14; color: ColorScheme.accent }
                            Text { text: high; anchors.horizontalCenter: parent.horizontalCenter; color: ColorScheme.text; font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                            Text { text: low; anchors.horizontalCenter: parent.horizontalCenter; color: ColorScheme.withAlpha(ColorScheme.text, 0.45); font.pixelSize: 9; font.family: "Inter" }
                        }
                    }
                }
            }

            // Error text
            Text {
                visible: root.errorText !== ""; text: root.errorText
                color: ColorScheme.red; font.pixelSize: 10; font.family: "Inter"
                Layout.fillWidth: true; elide: Text.ElideRight
            }

            // Config section (collapsible)
            Rectangle {
                id: configSection
                Layout.fillWidth: true; radius: 12
                color: ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.06); border.width: 1
                Layout.preferredHeight: root.configExpanded ? configCol.implicitHeight + 30 : 32
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                clip: true

                MouseArea {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 32; cursorShape: Qt.PointingHandCursor
                    onClicked: root.configExpanded = !root.configExpanded
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12; y: 9
                    text: "⚙ Location Settings"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.55)
                    font.pixelSize: 10; font.family: "Inter"
                }

                Text {
                    anchors.right: parent.right; anchors.rightMargin: 12; y: 9
                    text: root.configExpanded ? "▲" : "▼"
                    color: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                    font.pixelSize: 10
                }

                ColumnLayout {
                    id: configCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.topMargin: 32
                    anchors.margins: 12; spacing: 8

                    RowLayout {
                        Layout.fillWidth: true; spacing: 4

                        Rectangle {
                            id: modeCityBtn
                            property bool active: weatherConfig.mode === "city"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.22) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "City"; color: modeCityBtn.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6); font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: { weatherConfig.mode = "city"; root.requestLayoutRefresh(); } }
                        }
                        Rectangle {
                            id: modeCoordsBtn
                            property bool active: weatherConfig.mode === "coords"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.22) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "Coords"; color: modeCoordsBtn.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6); font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: { weatherConfig.mode = "coords"; root.requestLayoutRefresh(); } }
                        }
                        Rectangle {
                            id: modeAutoBtn
                            property bool active: weatherConfig.mode === "auto"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.22) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: root.geolocationPending ? "Locating..." : "Auto"; color: modeAutoBtn.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.6); font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: { weatherConfig.mode = "auto"; root.requestLayoutRefresh(); } }
                        }
                    }

                    TextField {
                        id: cityField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        visible: weatherConfig.mode === "city"
                        text: weatherConfig.city; placeholderText: "City name"
                        font.pixelSize: 10; font.family: "Inter"
                        topPadding: 8; bottomPadding: 8; leftPadding: 10; rightPadding: 10
                        color: ColorScheme.text
                        placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                        background: Rectangle {
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.10)
                            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                            border.width: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; visible: weatherConfig.mode === "coords"; spacing: 6
                        TextField {
                            id: latField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            text: weatherConfig.latitude; placeholderText: "Lat"
                            font.pixelSize: 10; font.family: "Inter"; color: ColorScheme.text
                            topPadding: 8; bottomPadding: 8; leftPadding: 10; rightPadding: 10
                            placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                            background: Rectangle {
                                radius: 9
                                color: Qt.rgba(1, 1, 1, 0.10)
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                                border.width: 1
                            }
                        }
                        TextField {
                            id: lonField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            text: weatherConfig.longitude; placeholderText: "Lon"
                            font.pixelSize: 10; font.family: "Inter"; color: ColorScheme.text
                            topPadding: 8; bottomPadding: 8; leftPadding: 10; rightPadding: 10
                            placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                            background: Rectangle {
                                radius: 9
                                color: Qt.rgba(1, 1, 1, 0.10)
                                border.color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                                border.width: 1
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        visible: weatherConfig.mode === "auto"
                        radius: 9
                        color: ColorScheme.withAlpha(ColorScheme.surface, 0.28)
                        Text {
                            anchors.centerIn: parent
                            text: root.geolocationPending ? "Resolving location..." : "Use current network location"
                            color: ColorScheme.withAlpha(ColorScheme.text, 0.75)
                            font.pixelSize: 10
                            font.family: "Inter"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshWeather(true)
                        }
                    }

                    TextField {
                        id: customNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        text: weatherConfig.customName; placeholderText: "Custom label (optional)"
                        font.pixelSize: 10; font.family: "Inter"; color: ColorScheme.text
                        topPadding: 8; bottomPadding: 8; leftPadding: 10; rightPadding: 10
                        placeholderTextColor: ColorScheme.withAlpha(ColorScheme.text, 0.35)
                        background: Rectangle {
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.10)
                            border.color: ColorScheme.withAlpha(ColorScheme.text, 0.18)
                            border.width: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            id: unitTempC
                            property bool active: (weatherConfig.unitsTemp || "C") === "C"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "°C"; color: unitTempC.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsTemp = "C" }
                        }
                        Rectangle {
                            id: unitTempF
                            property bool active: (weatherConfig.unitsTemp || "C") === "F"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "°F"; color: unitTempF.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsTemp = "F" }
                        }
                        Rectangle {
                            id: unitWindKmh
                            property bool active: (weatherConfig.unitsWind || "kmh") === "kmh"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "km/h"; color: unitWindKmh.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsWind = "kmh" }
                        }
                        Rectangle {
                            id: unitWindMph
                            property bool active: (weatherConfig.unitsWind || "kmh") === "mph"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "mph"; color: unitWindMph.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsWind = "mph" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            id: unitPressureHpa
                            property bool active: (weatherConfig.unitsPressure || "hPa") === "hPa"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "hPa"; color: unitPressureHpa.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsPressure = "hPa" }
                        }
                        Rectangle {
                            id: unitPressureInHg
                            property bool active: (weatherConfig.unitsPressure || "hPa") === "inHg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 13
                            color: active ? ColorScheme.withAlpha(ColorScheme.accent, 0.20) : ColorScheme.withAlpha(ColorScheme.surface, 0.25)
                            Text { anchors.centerIn: parent; text: "inHg"; color: unitPressureInHg.active ? ColorScheme.accent : ColorScheme.withAlpha(ColorScheme.text, 0.7); font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea { anchors.fill: parent; onClicked: weatherConfig.unitsPressure = "inHg" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: savedLocationsModel.count > 0

                        Repeater {
                            model: Math.min(4, savedLocationsModel.count)
                            delegate: Rectangle {
                                required property int index
                                readonly property var row: savedLocationsModel.get(index)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 12
                                color: ColorScheme.withAlpha(ColorScheme.surface, 0.22)
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var n = String(row.customName || "");
                                        if (n !== "") return n;
                                        if (String(row.mode || "city") === "city") return String(row.city || "City");
                                        return "Preset " + (index + 1);
                                    }
                                    color: ColorScheme.withAlpha(ColorScheme.text, 0.8)
                                    font.pixelSize: 9
                                    font.family: "Inter"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyPreset(index)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: saveMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.accent, 0.25) : ColorScheme.withAlpha(ColorScheme.accent, 0.15)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "Save & Refresh"; color: ColorScheme.accent; font.pixelSize: 10; font.bold: true; font.family: "Inter" }
                            MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveConfigFromForm() }
                        }

                        Rectangle {
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 28
                            radius: 14
                            color: presetMa.containsMouse ? ColorScheme.withAlpha(ColorScheme.blue, 0.22) : ColorScheme.withAlpha(ColorScheme.blue, 0.12)
                            Text { anchors.centerIn: parent; text: "Save preset"; color: ColorScheme.blue; font.pixelSize: 9; font.bold: true; font.family: "Inter" }
                            MouseArea {
                                id: presetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.saveConfigFromForm();
                                    root.saveCurrentAsPreset();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
