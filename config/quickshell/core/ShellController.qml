pragma Singleton
import QtQuick
import "./ErrorStateMachine.js" as ErrorStateMachine
import "./TextSanitizer.js" as TextSanitizer
import "./PopupRegistry.js" as PopupRegistry
import "../services"
import "../services/HealthService.js" as HealthService
import "../services/SanityService.js" as SanityService

QtObject {
    id: root

    function defaultContextData() {
        return {
            "path": "",
            "project_type": "desktop",
            "icon": "",
            "git_branch": "",
            "notes": "",
            "services": [],
            "issues": []
        };
    }

    function normalizeContextData(data) {
        var normalized = defaultContextData();
        if (!data || typeof data !== "object")
            return normalized;

        if (typeof data.path === "string")
            normalized.path = data.path;

        if (typeof data.project_type === "string" && data.project_type !== "")
            normalized.project_type = data.project_type;

        if (typeof data.icon === "string" && data.icon.trim() !== "")
            normalized.icon = data.icon;

        if (typeof data.git_branch === "string")
            normalized.git_branch = data.git_branch;

        if (typeof data.notes === "string")
            normalized.notes = data.notes;

        if (data.services && data.services.length !== undefined)
            normalized.services = data.services;

        if (data.issues && data.issues.length !== undefined)
            normalized.issues = data.issues;

        return normalized;
    }

    function updateRecoveryState(shellRoot, kind, scope, message, options) {
        if (!shellRoot)
            return;
        var opts = options || {};
        if (opts.sanitizeText === undefined)
            opts.sanitizeText = TextSanitizer.cleanSingleLineText;
        shellRoot.recoveryState = ErrorStateMachine.makeState(kind, scope, message, opts);
    }

    function bindSettingsStore(settingsStore) {
        ConfigFacade.bindStore(settingsStore);
    }

    function isPopupOpen(target) {
        return PopupRegistry.isOpen(target);
    }

    function anyBarPopupOpen(bar) {
        return PopupRegistry.anyBarPopupOpen(bar);
    }

    function openPopup(triggerItem, popup) {
        PopupUtils.openPopup(triggerItem, popup);
    }

    function closePopup(triggerItem, popup) {
        PopupUtils.closePopup(triggerItem, popup);
    }

    function togglePopup(triggerItem, popup) {
        PopupUtils.togglePopup(triggerItem, popup);
    }

    function loadUiPreferences() {
        FeatureFlags.barCompactMode = ConfigFacade.barCompactMode();
        FeatureFlags.barAutoHide = ConfigFacade.barAutoHide();
        FeatureFlags.barDndVisualMode = ConfigFacade.barDndVisualMode();
        FeatureFlags.reducedMotion = ConfigFacade.reducedMotion() || FeatureFlags.lowPowerUiMode;
        FeatureFlags.privacyMode = ConfigFacade.privacyMode();
        FeatureFlags.focusMode = ConfigFacade.focusMode();
    }

    function setFocusMode(enabled) {
        var next = enabled === true;
        if (FeatureFlags.focusMode === next)
            return;

        FeatureFlags.focusMode = next;
        ConfigFacade.set("focusMode", next);
    }

    function toggleFocusMode() {
        setFocusMode(!FeatureFlags.focusMode);
    }

    function restoreBatteryPreferences(batteryPowerProfileProc, batteryNightLightProc, batteryGrayscaleProc) {
        if (!ConfigFacade.batteryPrefsInitialized())
            return;

        var profile = ConfigFacade.batteryPowerProfile();
        if (profile === "power-saver" || profile === "balanced" || profile === "performance")
            batteryPowerProfileProc.exec(["powerprofilesctl", "set", profile]);

        BatteryStatsService.setLimitActive(ConfigFacade.batteryLimitActive());
        BatteryStatsService.setCaffeineActive(ConfigFacade.batteryCaffeineActive());
    }

    function openLazyItem(item) {
        if (!item)
            return;
        if (item.isOpen !== undefined)
            item.isOpen = true;
        else if (item.visible !== undefined)
            item.visible = true;
    }

    function toggleLazyItem(item, label) {
        if (!item)
            return;
        if (item.isOpen !== undefined) {
            item.isOpen = !item.isOpen;
            return;
        }
        if (item.visible !== undefined) {
            item.visible = !item.visible;
            return;
        }
        console.warn("[LazyLoader] toggle failed (no isOpen/visible): " + (label || "unknown"));
    }

    function toggleLazyWindow(loader) {
        if (!loader)
            return;
        if (!loader.active) {
            loader.active = true;
            return;
        }
        toggleLazyItem(loader.item, loader.objectName);
    }

    function wireLoaderTeardown(item, loader) {
        if (!item || !loader || item.closedAndReady === undefined)
            return;

        var i = item;
        var l = loader;
        var handler = function() {
            i.closedAndReady.disconnect(handler);
            Qt.callLater(function() {
                if (l.active && l.item && !l.item.isOpen)
                    l.active = false;
            });
        };
        item.closedAndReady.connect(handler);
    }

    function collectPopupIssues(shellRoot) {
        return PopupUtils.missingShellPopups(shellRoot);
    }

    function runHealthCheck(shellRoot, healthCheckProc) {
        shellRoot.healthChecked = false;
        updateRecoveryState(shellRoot, "loading", "Saúde", "Verificando binários", { sanitizeText: TextSanitizer.cleanSingleLineText });
        healthCheckProc.exec(HealthService.checkArgs());
    }

    function applyHealthStatus(shellRoot, payload) {
        var status = HealthService.parseStatus(payload);
        shellRoot.binaryHealth = status;
        shellRoot.healthChecked = true;

        var missing = [];
        for (var key in status) {
            if (status[key] !== true)
                missing.push(key);
        }

        if (missing.length > 0)
            updateRecoveryState(shellRoot, "degraded", "Saúde", "Dependências ausentes: " + missing.join(", "), { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        else
            updateRecoveryState(shellRoot, "ready", "Saúde", "Dependências verificadas", { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
    }

    function runSanityCheck(shellRoot, sanityCheckProc) {
        shellRoot.sanityIssues = collectPopupIssues(shellRoot);
        updateRecoveryState(shellRoot, "loading", "Sanidade", "Validando superfícies", { sanitizeText: TextSanitizer.cleanSingleLineText });
        sanityCheckProc.exec(SanityService.checkArgs());
    }

    function finishSanityCheck(shellRoot, parsed, sanityNotifyProc) {
        var issues = [];
        for (var i = 0; i < shellRoot.sanityIssues.length; i++)
            issues.push("popup:" + shellRoot.sanityIssues[i]);

        var failedServices = SanityService.failedKeys(parsed);
        for (var j = 0; j < failedServices.length; j++)
            issues.push("svc:" + failedServices[j]);

        shellRoot.sanityIssues = issues;

        if (issues.length > 0) {
            updateRecoveryState(shellRoot, "degraded", "Sanidade", issues.join(", "), { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
            sanityNotifyProc.exec([
                "notify-send",
                "-a", "Quickshell",
                "Sanity check com alertas",
                issues.join(", ")
            ]);
        } else {
            updateRecoveryState(shellRoot, "ready", "Sanidade", "Superfícies consistentes", { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        }
    }

    function setDndState(notificationPopupWindow, enabled) {
        if (notificationPopupWindow)
            notificationPopupWindow.muted = enabled === true || enabled === 1 || enabled === "1";
    }

    function applyLowPowerMode(shellRoot, enabled, lowPowerProc, sanityNotifyProc) {
        var active = enabled === true;
        if (shellRoot.lowPowerApplied === active)
            return;

        shellRoot.lowPowerApplied = active;
        FeatureFlags.lowPowerUiMode = active;
        FeatureFlags.reducedMotion = active || ConfigFacade.reducedMotion();
        lowPowerProc.exec([
            "bash",
            RuntimePaths.scriptFile("low_power_mode_apply.sh"),
            active ? "on" : "off"
        ]);
        sanityNotifyProc.exec([
            "notify-send",
            "-a", "Quickshell",
            "Battery saver UI",
            active ? "Modo economia ativado" : "Modo economia desativado"
        ]);
    }

    function parseBatteryPercent(shellRoot, rawText, lowPowerProc, sanityNotifyProc) {
        var val = Number(String(rawText || "").trim());
        if (!isFinite(val))
            return;
        applyLowPowerMode(shellRoot, val <= shellRoot.lowPowerThreshold, lowPowerProc, sanityNotifyProc);
    }

    function onContextDaemonExited(shellRoot, daemonRestartTimer, daemonHealthTimer, contextDaemon) {
        daemonHealthTimer.stop();
        shellRoot.daemonRetry = Math.min(shellRoot.daemonRetry + 1, 8);
        daemonRestartTimer.interval = shellRoot.daemonRetry < 3
            ? Math.min(60000, 5000 * shellRoot.daemonRetry)
            : 60000;
        updateRecoveryState(shellRoot, "degraded", "Context daemon", "Reiniciando daemon do contexto", { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        shellRoot.shellState = "degraded";
        daemonRestartTimer.restart();
    }

    function onContextDaemonRecovered(shellRoot) {
        if (shellRoot.shellState === "degraded" && shellRoot.daemonRetry === 0)
            shellRoot.shellState = "ready";
    }

    function notifyContextDaemonFailure(shellRoot, notifyProc, payload) {
        if (!payload || payload.label !== "context-daemon")
            return;
        if (!notifyProc || !notifyProc.exec) {
            console.warn("[ShellController] missing notifier for context daemon failure");
            return;
        }

        var exitCode = Number(payload.exitCode);
        if (!isFinite(exitCode))
            exitCode = -1;

        var failures = Number(payload.failures);
        if (!isFinite(failures) || failures < 1)
            failures = Math.max(1, Number(shellRoot.daemonRetry || 0) + 1);

        var restartDelayMs = failures < 3 ? 5000 * failures : 60000;
        updateRecoveryState(shellRoot, "error", "Context daemon", "Saída " + exitCode + " · tentativa " + failures + " · reinício em " + Math.round(restartDelayMs / 1000) + "s", { sanitizeText: TextSanitizer.cleanSingleLineText, recoverable: true });
        shellRoot.shellState = "degraded";

        notifyProc.exec([
            "notify-send",
            "-a", "Quickshell",
            "Context daemon caiu",
            "Saida " + exitCode + " · tentativa " + failures + " · reinicio em " + Math.round(restartDelayMs / 1000) + "s"
        ]);
    }

    function updateContext(shellRoot, payload) {
        try {
            var data = JSON.parse(payload);
            shellRoot.contextData = normalizeContextData(data);
        } catch (e) {
            console.warn("[IPC] Failed to parse context data: " + e);
        }
    }
}
