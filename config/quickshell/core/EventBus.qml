pragma Singleton
import QtQuick

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal event(string topic, var payload)

    QtObject {
        id: processNamespace
        signal succeeded(var payload)
        signal failed(var payload)
        signal timeout(var payload)

        function publishSucceeded(payload) {
            succeeded(payload);
            root.event("process.succeeded", payload);
        }

        function publishFailed(payload) {
            failed(payload);
            root.event("process.failed", payload);
        }

        function publishTimeout(payload) {
            timeout(payload);
            root.event("process.timeout", payload);
        }
    }

    QtObject {
        id: weatherNamespace
        signal error(var payload)
        signal cacheUpdated(var payload)

        function publishError(payload) {
            error(payload);
            root.event("weather.error", payload);
        }

        function publishCacheUpdated(payload) {
            cacheUpdated(payload);
            root.event("weather.cacheUpdated", payload);
        }
    }

    QtObject {
        id: performanceNamespace
        signal budgetMeasured(var payload)

        function publishBudgetMeasured(payload) {
            budgetMeasured(payload);
            root.event("perf.budget", payload);
        }
    }

    QtObject {
        id: dockNamespace
        signal toggleWorkspaceIsolation(var payload)

        function publishToggleWorkspaceIsolation(payload) {
            toggleWorkspaceIsolation(payload);
            root.event("dock:toggleWorkspaceIsolation", payload);
        }
    }

    QtObject {
        id: componentNamespace
        signal loadFailure(var payload)

        function publishLoadFailure(payload) {
            loadFailure(payload);
            root.event("component.loadFailure", payload);
        }
    }

    readonly property QtObject process: processNamespace
    readonly property QtObject weather: weatherNamespace
    readonly property QtObject performance: performanceNamespace
    readonly property QtObject dock: dockNamespace
    readonly property QtObject component: componentNamespace

    function publish(topic, payload) {
        if (topic === "process.succeeded") {
            process.publishSucceeded(payload);
            return;
        }
        if (topic === "process.failed") {
            process.publishFailed(payload);
            return;
        }
        if (topic === "process.timeout") {
            process.publishTimeout(payload);
            return;
        }
        if (topic === "weather.error") {
            weather.publishError(payload);
            return;
        }
        if (topic === "weather.cacheUpdated") {
            weather.publishCacheUpdated(payload);
            return;
        }
        if (topic === "perf.budget") {
            performance.publishBudgetMeasured(payload);
            return;
        }
        if (topic === "dock:toggleWorkspaceIsolation") {
            dock.publishToggleWorkspaceIsolation(payload);
            return;
        }
        if (topic === "component.loadFailure") {
            component.publishLoadFailure(payload);
            return;
        }
        event(topic, payload);
    }
}
