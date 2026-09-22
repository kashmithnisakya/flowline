"""The workspace read every page fires together with its own data, cached
for a minute in module state. The runtime's own reader cache is flushed by
any walker it cannot classify (every task list, by design), and a page fires
one in the same batch, so this cell is what actually serves a second mount;
BoardSnapshot primes it from the board's own result and every roster writer
calls forgetWorkspace() after its write.
"""

import from ..services.workspace.workspace { GetWorkspace }

glob TTL_MS: float = 60000.0,
     CACHE: dict[str, any] = {"view": None, "at": 0.0, "promise": None};

# The last view, when it landed (ms) and the read in flight, so two mounts
# in the same tick make one request. A dict cell, not a `has`: every page
# reads the same one, and a full page load starts it empty.
# The shape a failed read comes back as: every list empty, nothing connected.
def emptyWorkspace -> dict[str, any] {
    return {
        "ok": False,
        "members": [],
        "projects": [],
        "steps": [],
        "repos": [],
        "roles": [],
        "iterations": [],
        "filter_sets": [],
        "github_connected": False,
        "flow_name": "Flow line",
        "template_key": "",
        "github": None,
        "webhook_live": False
    };
}

# A WorkspaceView (or a BoardData, which carries the same fields) as the
# dict pages consume.
def shapeOf(view: any) -> dict[str, any] {
    return {
        "ok": True,
        "members": view.members,
        "projects": view.projects,
        "steps": view.steps,
        "repos": view.repos,
        "roles": view.roles,
        "iterations": view.iterations,
        "filter_sets": view.filter_sets,
        "github_connected": view.github_connected,
        "flow_name": view.flow_name,
        "template_key": view.template_key,
        "github": view.github,
        "webhook_live": view.webhook_live
    };
}

# Keep this view as the workspace for the next minute. The board calls it
# with its snapshot, so the pages after it mount without a request.
def:pub rememberWorkspace(view: any) {
    d = new(Date);
    CACHE["view"] = shapeOf(view);
    CACHE["at"] = d.getTime();
}

# Drop the cached view: every roster writer calls this right after its
# write, before any refetch, and a session change does too.
def:pub forgetWorkspace {
    CACHE["view"] = None;
    CACHE["at"] = 0.0;
    CACHE["promise"] = None;
}

def fresh -> bool {
    if CACHE["view"] is None {
        return False;
    }
    d = new(Date);
    return (d.getTime() as float) - (CACHE["at"] as float) < TTL_MS;
}

async def fetchWorkspace -> dict[str, any] {
    try {
        result = root spawn GetWorkspace();
        view: any = result.reports[0] if result.reports else None;
        if not view {
            return emptyWorkspace();
        }
        rememberWorkspace(view);
        return shapeOf(view);
    } except Exception as e {
        return emptyWorkspace();
    }
}

# The workspace view: the cached one while it is younger than TTL_MS,
# otherwise one GetWorkspace shared by every caller until it lands. A
# failed read is the empty shape and leaves nothing cached.
async def:pub loadWorkspace -> dict[str, any] {
    if fresh() {
        return CACHE["view"];
    }
    if not CACHE["promise"] {
        CACHE["promise"] = fetchWorkspace();
    }
    promise: any = CACHE["promise"];
    result = await promise;
    if CACHE["promise"] == promise {
        CACHE["promise"] = None;
    }
    return result;
}
