.pragma library

function nextState(currentAction, nextAction) {
    var current = String(currentAction || "");
    var action = String(nextAction || "");
    var confirmed = current !== "" && current === action;

    return {
        confirmed: confirmed,
        confirmingAction: confirmed ? "" : action
    };
}
