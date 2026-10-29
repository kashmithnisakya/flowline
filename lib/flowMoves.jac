"""Position writes belong to the browser session, not a mounted flow page.
Keep every accepted drop in order across navigation, and retain its preview
until a current server read confirms the position."""

import from "sonner" { toast }
import from ..services.flowlines.flowlines { MoveStep }
import from .workspace { forgetWorkspace }

glob STORE: dict[str, any] = {"session": "", "moves": None};

def moveState -> dict[str, any] {
    session = localStorage.getItem("jac_token") or "";
    if STORE["moves"] is None or STORE["session"] != session {
        STORE["session"] = session;
        STORE["moves"] = {
            "version": 0,
            "queue": [],
            "pending": {},
            "saving": False,
            "promise": None
        };
    }
    return STORE["moves"] as dict[str, any];
}

def:pub flowMoveVersion -> int {
    return int(moveState()["version"]);
}

def:pub advanceFlowMove {
    state = moveState();
    state["version"] = int(state["version"]) + 1;
}

def:pub pendingFlowMoves -> dict[str, list[float]] {
    state = moveState();
    return {** (state["pending"] as dict[str, list[float]])};
}

def:pub flowMovesBusy -> bool {
    state = moveState();
    queued = state["queue"] as list[dict[str, any]];
    return bool(state["saving"]) or len(queued) > 0;
}

def:pub queueFlowMove(stepId: str, x: float, y: float) {
    state = moveState();
    advanceFlowMove();
    queued = state["queue"] as list[dict[str, any]];
    state["queue"] = queued + [{"id": stepId, "x": x, "y": y}];
    pending = {** (state["pending"] as dict[str, list[float]])};
    pending[stepId] = [x, y];
    state["pending"] = pending;
}

async def drainMoves(state: dict[str, any]) {
    state["saving"] = True;
    try {
        while state == moveState() {
            queued = state["queue"] as list[dict[str, any]];
            if len(queued) == 0 {
                break;
            }
            move = queued[0];
            state["queue"] = queued[1:];
            try {
                root spawn MoveStep(
                    step_id=str(move["id"]), x=float(move["x"]), y=float(move["y"])
                );
                if state == moveState() {
                    forgetWorkspace();
                }
            } except Exception {
                if state == moveState() {
                    toast.error("Failed to save the position");
                }
            }
            # A read started while this write was pending cannot confirm
            # its outcome, even when it arrives after a newer refresh.
            if state == moveState() {
                advanceFlowMove();
            }
        }
    } finally {
        state["saving"] = False;
        if state == moveState() {
            w: any = window;
            w.dispatchEvent(new(w.CustomEvent, "flowline:moves-saved"));
        }
    }
}

async def:pub flushFlowMoves {
    state = moveState();
    if state["promise"] {
        await state["promise"];
        return;
    }
    queued = state["queue"] as list[dict[str, any]];
    if len(queued) == 0 {
        return;
    }
    promise: any = drainMoves(state);
    state["promise"] = promise;
    try {
        await promise;
    } finally {
        if state["promise"] == promise {
            state["promise"] = None;
        }
    }
}

def:pub acknowledgeFlowMoves(version: int) {
    state = moveState();
    if version == int(state["version"]) and not flowMovesBusy() {
        state["pending"] = {};
    }
}
