"""standup - shared vocabulary lists."""

glob STATUSES: list[str] = ["Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"];
glob PRIORITIES: list[str] = ["High", "Medium", "Low"];
glob MILESTONE_STATUSES: list[str] = ["Planned", "In Progress", "Done"];

# What a workflow step MEANS, independent of what the org names it. The rest
# of the app keys behavior on the kind ("done" is terminal, "blocked" raises
# attention, "handoff" is waiting on someone), so renaming a step is always
# safe and every workflow needs at least a start and a done to be complete.
glob STEP_KINDS: list[str] = ["start", "active", "handoff", "blocked", "done"];

# Default color key per kind; the step stores the key, the client maps it to
# literal Tailwind classes.
glob KIND_COLORS: dict[str, str] = {
    "start": "sky", "active": "indigo", "handoff": "amber",
    "blocked": "rose", "done": "emerald"
};

# Seed data for ApplyTemplate AND the picker's mini previews: one source, so
# the preview can never drift from what actually gets created. `links` pairs
# are indexes into `steps`; x/y are designer-canvas px.
glob WORKFLOW_TEMPLATES: list[dict[str, any]] = [
    {
        "key": "kanban",
        "name": "Classic Kanban",
        "description": "The straight line you know: To do, In progress, Done.",
        "steps": [
            {"name": "To do", "kind": "start", "color": "sky", "x": 40.0, "y": 60.0},
            {"name": "In progress", "kind": "active", "color": "indigo", "x": 300.0, "y": 60.0},
            {"name": "Done", "kind": "done", "color": "emerald", "x": 560.0, "y": 60.0}
        ],
        "links": [[0, 1], [1, 2]]
    },
    {
        "key": "software",
        "name": "Software flow",
        "description": "Review loops back to development. Mirrors the classic six statuses.",
        "steps": [
            {"name": "Backlog", "kind": "start", "color": "sky", "x": 40.0, "y": 40.0},
            {"name": "In progress", "kind": "active", "color": "indigo", "x": 300.0, "y": 40.0},
            {"name": "Review", "kind": "handoff", "color": "amber", "x": 560.0, "y": 40.0},
            {"name": "Changes requested", "kind": "active", "color": "indigo", "x": 560.0, "y": 220.0},
            {"name": "Blocked", "kind": "blocked", "color": "rose", "x": 300.0, "y": 220.0},
            {"name": "Done", "kind": "done", "color": "emerald", "x": 820.0, "y": 120.0}
        ],
        "links": [[0, 1], [1, 2], [2, 5], [2, 3], [3, 1], [1, 4], [4, 1]]
    },
    {
        "key": "support",
        "name": "Support flow",
        "description": "Triage, work, wait on the customer, resolve. Waiting loops back.",
        "steps": [
            {"name": "New", "kind": "start", "color": "sky", "x": 40.0, "y": 60.0},
            {"name": "Triage", "kind": "active", "color": "indigo", "x": 300.0, "y": 60.0},
            {"name": "In progress", "kind": "active", "color": "indigo", "x": 560.0, "y": 60.0},
            {"name": "Waiting on customer", "kind": "handoff", "color": "amber", "x": 560.0, "y": 240.0},
            {"name": "Resolved", "kind": "done", "color": "emerald", "x": 820.0, "y": 140.0}
        ],
        "links": [[0, 1], [1, 2], [2, 3], [3, 2], [2, 4]]
    }
];
