"""The workspace read every page fires together with its own data. One
GetWorkspace call answers as a plain dict keyed like WorkspaceView, plus
`ok`; a failed read is the empty shape, so a page keeps its own
failed-load handling and never sees an exception from here.
"""

import from ..services.workspace.workspace { GetWorkspace }

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
        "github_connected": False,
        "flow_name": "Flow line",
        "template_key": "",
        "github": None
    };
}

async def:pub loadWorkspace -> dict[str, any] {
    try {
        result = root spawn GetWorkspace();
        view: any = result.reports[0] if result.reports else None;
        if not view {
            return emptyWorkspace();
        }
        return {
            "ok": True,
            "members": view.members,
            "projects": view.projects,
            "steps": view.steps,
            "repos": view.repos,
            "roles": view.roles,
            "iterations": view.iterations,
            "github_connected": view.github_connected,
            "flow_name": view.flow_name,
            "template_key": view.template_key,
            "github": view.github
        };
    } except Exception as e {
        return emptyWorkspace();
    }
}
