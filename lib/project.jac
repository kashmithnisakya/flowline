"""The project the board, the flow line and the roadmap are scoped to. It
lives in this browser (PROJECT_KEY) so every page opens on the same one;
the sidebar and the pages' own pickers change it through pickProject, which
tells every mounted listener with a `flowline:project` window event."""

glob:pub PROJECT_KEY: str = "flowline_project";

# The picked project's jid, "" before anything was picked.
def:pub currentProject -> str {
    try {
        return localStorage.getItem(PROJECT_KEY) or "";
    } except Exception as e {
        return "";
    }
}

# Scope every page to `projectId` and tell the mounted ones.
def:pub pickProject(projectId: str) {
    w: any = window;
    try {
        localStorage.setItem(PROJECT_KEY, projectId);
    } except Exception as e {
        w.console.warn("The project pick is not kept in this browser", e);
    }
    w.dispatchEvent(new(w.CustomEvent, "flowline:project", {"detail": projectId}));
}
