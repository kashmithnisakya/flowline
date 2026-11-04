"""Order accepted note writes across inspector and page remounts.
Different notes remain independent; changing accounts cancels queued writes."""

import from ..services.processes.processes { SaveProcessNote }

glob STORE: dict[str, any] = {"session": "", "notes": None};

def noteState -> dict[str, any] {
    session = localStorage.getItem("jac_token") or "";
    if STORE["notes"] is None or STORE["session"] != session {
        STORE["session"] = session;
        STORE["notes"] = {"tails": {}};
    }
    return STORE["notes"] as dict[str, any];
}

def:pub processNotesBusy -> bool {
    tails = noteState()["tails"] as dict[str, any];
    return len(tails) > 0;
}

async def sendNote(
    state: dict[str, any], previous: any, processId: str, stepId: str, note: str
) -> dict[str, any] {
    if previous {
        try {
            await previous;
        } except Exception {
            # A failed earlier write must not discard a later accepted save.
        }
    }
    if state != noteState() {
        return {"ok": False, "error": "session_changed"};
    }
    result = root spawn SaveProcessNote(
        process_id=processId, step_id=stepId, note=note
    );
    if state != noteState() {
        return {"ok": False, "error": "session_changed"};
    }
    return result.reports[0] if result.reports else {"ok": False};
}

async def:pub saveProcessNote(
    processId: str, stepId: str, note: str
) -> dict[str, any] {
    state = noteState();
    tails = state["tails"] as dict[str, any];
    key = processId + ":" + stepId;
    promise: any = sendNote(state, tails.get(key, None), processId, stepId, note);
    tails[key] = promise;
    try {
        return await promise;
    } finally {
        if tails.get(key, None) == promise {
            tails.pop(key, None);
        }
    }
}
