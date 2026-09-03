.pragma library

function _string(value) {
    if (value === undefined || value === null)
        return "";
    return String(value);
}

function _bool(value, fallbackValue) {
    if (value === true || value === 1 || value === "1")
        return true;
    if (value === false || value === 0 || value === "0")
        return false;
    return fallbackValue === true;
}

function _int(value, fallbackValue) {
    var num = Number(value);
    if (!isFinite(num) || isNaN(num))
        return Number(fallbackValue || 0);
    return Math.max(0, Math.floor(num));
}

function defaultLauncherState() {
    return {
        version: 1,
        searchText: "",
        selectedIndex: 0,
        selectedItemKey: "",
        categoryFilter: "",
        filterBarIndex: 0,
        filterBarOpen: false,
        cheatSheetOpen: false
    };
}

function normalizeLauncherState(raw) {
    var state = defaultLauncherState();
    if (!raw || typeof raw !== "object")
        return state;

    if (raw.searchText !== undefined)
        state.searchText = _string(raw.searchText);
    else if (raw.query !== undefined)
        state.searchText = _string(raw.query);

    if (raw.selectedIndex !== undefined)
        state.selectedIndex = _int(raw.selectedIndex, state.selectedIndex);
    else if (raw.currentIndex !== undefined)
        state.selectedIndex = _int(raw.currentIndex, state.selectedIndex);

    if (raw.selectedItemKey !== undefined)
        state.selectedItemKey = _string(raw.selectedItemKey);

    if (raw.categoryFilter !== undefined)
        state.categoryFilter = _string(raw.categoryFilter);

    if (raw.filterBarIndex !== undefined)
        state.filterBarIndex = _int(raw.filterBarIndex, state.filterBarIndex);

    if (raw.filterBarOpen !== undefined)
        state.filterBarOpen = _bool(raw.filterBarOpen, state.filterBarOpen);

    if (raw.cheatSheetOpen !== undefined)
        state.cheatSheetOpen = _bool(raw.cheatSheetOpen, state.cheatSheetOpen);

    return state;
}

function encodeLauncherState(state) {
    return JSON.stringify(normalizeLauncherState(state));
}

function decodeLauncherState(text) {
    try {
        return normalizeLauncherState(JSON.parse(_string(text)));
    } catch (e) {
        return defaultLauncherState();
    }
}
