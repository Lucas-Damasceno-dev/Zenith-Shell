pragma Singleton
import QtQuick

QtObject {
    id: root

    property var settingsStore: null

    function bindStore(store) {
        settingsStore = store;
    }

    function hasStore() {
        return !!(settingsStore && settingsStore.get && settingsStore.set);
    }

    function get(key, fallbackValue) {
        if (!hasStore())
            return fallbackValue;
        return settingsStore.get(key, fallbackValue);
    }

    function set(key, value) {
        if (!hasStore())
            return;
        settingsStore.set(key, value);
    }

    function getBoolean(key, fallbackValue) {
        return get(key, fallbackValue === true) === true;
    }

    function getString(key, fallbackValue) {
        var value = get(key, fallbackValue !== undefined ? fallbackValue : "");
        if (value === undefined || value === null)
            return fallbackValue !== undefined ? String(fallbackValue) : "";
        return String(value);
    }

    function getNumber(key, fallbackValue) {
        var value = Number(get(key, fallbackValue));
        if (!isFinite(value))
            return Number(fallbackValue || 0);
        return value;
    }

    function choiceValue(key, allowedValues, fallbackValue) {
        var value = String(getString(key, fallbackValue)).trim().toLowerCase();
        var fallback = String(fallbackValue || "").trim();
        for (var i = 0; i < allowedValues.length; i++) {
            var candidate = String(allowedValues[i] || "").trim();
            if (candidate !== "" && value === candidate.toLowerCase())
                return candidate;
        }
        return fallback;
    }

    function barCompactMode() { return getBoolean("barCompactMode", false); }
    function barAutoHide() { return getBoolean("barAutoHide", true); }
    function barDndVisualMode() { return get("barDndVisualMode", true) !== false; }
    function reducedMotion() { return getBoolean("reducedMotion", false); }
    function privacyMode() { return getBoolean("privacyMode", false); }
    function focusMode() { return getBoolean("focusMode", false); }
    function popupCenterOffsetY() { return getNumber("popupCenterOffsetY", 12); }
    function contextProfile() { return choiceValue("contextProfile", ["work", "study", "gaming", "streaming", "presentation"], "work"); }
    function networkActiveView() { return choiceValue("networkActiveView", ["wifi", "bt"], "wifi"); }
    function systemMonitorSortMode() { return choiceValue("systemMonitorSortMode", ["cpu", "mem"], "cpu"); }
    function systemMonitorFilter() { return getString("systemMonitorFilter", ""); }
    function systemMonitorActiveTab() { return choiceValue("systemMonitorActiveTab", ["processes", "services"], "processes"); }

    function utilityMicEnabled() { return getBoolean("utilityMicEnabled", false); }
    function utilitySystemEnabled() { return getBoolean("utilitySystemEnabled", false); }
    function utilityAnonymizeCapture() { return getBoolean("utilityAnonymizeCapture", false); }
    function utilityScreenshotFormat() { return choiceValue("utilityScreenshotFormat", ["png", "jpg", "webp"], "png"); }
    function utilityScreenshotMode() { return choiceValue("utilityScreenshotMode", ["full", "window", "region"], "full"); }
    function utilityScreenshotDelaySec() { return Math.max(0, Math.min(10, Math.round(getNumber("utilityScreenshotDelaySec", 0)))); }
    function utilityVideoContainer() { return choiceValue("utilityVideoContainer", ["mkv", "mp4"], "mkv"); }
    function utilityVideoCodec() { return choiceValue("utilityVideoCodec", ["libx264", "h264", "libvpx-vp9"], "libx264"); }
    function utilityVideoFps() { return getNumber("utilityVideoFps", 30); }
    function utilityVideoQuality() { return getNumber("utilityVideoQuality", 23); }
    function utilityScreenshotDir() { return getString("utilityScreenshotDir", ""); }
    function utilityVideoDir() { return getString("utilityVideoDir", ""); }
    function utilityFileTemplate() { return getString("utilityFileTemplate", "{type}_{timestamp}"); }
    function utilityCopyPathThumb() { return getBoolean("utilityCopyPathThumb", false); }
    function utilityLensProvider() { return choiceValue("utilityLensProvider", ["google", "bing", "yandex"], "google"); }
    function utilityOcrLang() { return getString("utilityOcrLang", "eng"); }

    function audioPreferredSink() { return getString("audioPreferredSink", ""); }
    function audioPreferredSource() { return getString("audioPreferredSource", ""); }
    function audioAppMixerPresetsJson() { return get("audioAppMixerPresetsJson", ({})); }
    function mediaSpectrumEnabled() { return getBoolean("mediaSpectrumEnabled", false); }

    function batteryPrefsInitialized() { return getBoolean("batteryPrefsInitialized", false); }
    function batteryNightLightValue() { return getNumber("batteryNightLightValue", 0); }
    function batteryGrayscaleValue() { return getNumber("batteryGrayscaleValue", 0); }
    function batteryPowerProfile() { return choiceValue("batteryPowerProfile", ["power-saver", "balanced", "performance"], "balanced"); }
    function batteryLimitActive() { return getBoolean("batteryLimitActive", false); }
    function batteryCaffeineActive() { return getBoolean("batteryCaffeineActive", false); }
}
