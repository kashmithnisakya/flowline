"""Implementations for the Agents tab."""

# The dialog's one bag of callbacks, so the panel's body stays a layout.
impl AgentsPanel.makeHandlers -> dict[str, any] {
    return {
        "onOpenChange": lambda (o: bool) { open = o; },
        "onField": setField,
        "onPickRole": pickRole,
        "onAllRoles": lambda { makeForEveryRole(); },
        "onToggleStep": lambda (id: str) { flip("steps", id); },
        "onToggleProject": lambda (id: str) { flip("projects", id); },
        "onToggleDuty": toggleDuty,
        "onAccess": setAccess,
        "onToggleTool": toggleTool,
        "onGoKeys": lambda {
            open = False;
            onGoKeys();
        },
        "onNext": next,
        "onBack": back
    };
}

impl AgentsPanel.load -> None {
    try {
        shared = await loadWorkspace();
        read = root spawn ListAgents();
        keyed = root spawn ListAiKeys();
        agents = read.reports[0] if read.reports else [];
        roles = shared["roles"];
        steps = shared["steps"];
        projects = shared["projects"];
        keys: any = keyed.reports[0] if keyed.reports else None;
        if keys {
            models = keys.models;
            defaultModel = keys.default_model;
        }
    } except Exception as e {
        toast.error("Could not load the agents");
    }
    loading = False;
}

impl AgentsPanel.startCreate -> None {
    draft = blankAgent(defaultModel);
    editing = False;
    step = 0;
    open = True;
}

impl AgentsPanel.startEdit(a: AgentView) -> None {
    draft = draftOf(a);
    editing = True;
    step = 0;
    open = True;
}

impl AgentsPanel.setField(key: str, value: any) -> None {
    updated = {** draft};
    updated[key] = value;
    draft = updated;
}

impl AgentsPanel.pickRole(id: str) -> None {
    updated = {** draft};
    updated["role_id"] = id;
    for r in roles {
        if r.id == id and (draft["name"] == "" or draft["name"].endswith(" agent")) {
            updated["name"] = r.name + " agent";
        }
    }
    draft = updated;
    if not editing {
        picked = {** updated};
        for r in roles {
            if r.id == id {
                picked["duties"] = [];
            }
        }
        draft = picked;
    }
}

# The draft's list with `id` added or taken out.
impl AgentsPanel.flip(key: str, id: str) -> None {
    held: list[str] = draft[key];
    kept: list[str] = [];
    present = False;
    for x in held {
        if x == id {
            present = True;
        } else {
            kept.append(x);
        }
    }
    if not present {
        kept.append(id);
    }
    updated = {** draft};
    updated[key] = kept;
    if key == "steps" {
        updated["event"] = "";
    }
    draft = updated;
}

impl AgentsPanel.toggleDuty(key: str) -> None {
    held: list[str] = draft["duties"];
    kept: list[str] = [];
    present = False;
    for x in held {
        if x == key {
            present = True;
        } else {
            kept.append(x);
        }
    }
    if not present {
        kept.append(key);
    }
    updated = {** draft};
    updated["duties"] = kept;
    draft = applyDuties(updated, steps);
}

impl AgentsPanel.setAccess(kind: str, on: bool) -> None {
    draft = withAccess(draft, kind, on);
}

impl AgentsPanel.toggleTool(key: str) -> None {
    kept: list[str] = [];
    present = False;
    for x in draft["tools"] {
        if x == key {
            present = True;
        } else {
            kept.append(x);
        }
    }
    if not present {
        kept.append(key);
    }
    updated = {** draft};
    updated["tools"] = kept;
    draft = updated;
}

impl AgentsPanel.next -> None {
    if step < 4 {
        step = step + 1;
        return;
    }
    save();
}

impl AgentsPanel.back -> None {
    if step > 0 {
        step = step - 1;
    } else {
        open = False;
    }
}

impl AgentsPanel.save -> None {
    if saving {
        return;
    }
    saving = True;
    try {
        result = root spawn SaveAgent(
            agent_id=draft["id"],
            name=draft["name"],
            role_id=draft["role_id"],
            projects=draft["projects"],
            steps=draft["steps"],
            event=draft["event"],
            tools=draft["tools"],
            access=draft["access"],
            mode=draft["mode"],
            duties=draft["duties"],
            prompt=draft["prompt"],
            rules=draft["rules"],
            model=draft["model"]
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            open = False;
            made = answer["agent"];
            forgetWorkspace();
            await load();
            if editing {
                toast.success("Saved " + made.name);
            } else {
                navigate("/agent?id=" + made.id);
            }
        } else {
            toast.error(answer["message"] if answer else "Could not save that agent");
        }
    } except Exception as e {
        toast.error("Could not save that agent");
    }
    saving = False;
}

impl AgentsPanel.toggle(id: str, wanted: bool) -> None {
    busyId = id;
    try {
        result = root spawn SetAgentEnabled(agent_id=id, enabled=wanted);
        answer: any = result.reports[0] if result.reports else None;
        if answer and not answer["ok"] {
            toast.error(answer["message"]);
        }
        forgetWorkspace();
        await load();
    } except Exception as e {
        toast.error("Could not change that agent");
    }
    busyId = "";
}

impl AgentsPanel.remove(target: AgentView) -> None {
    busyId = target.id;
    try {
        root spawn DeleteAgent(agent_id=target.id);
        forgetWorkspace();
        await load();
        toast.success("Agent deleted");
    } except Exception as e {
        toast.error("Could not delete that agent");
    }
    busyId = "";
}

# One agent per role that has none, each starting from that role's usual
# responsibilities, left off until a model is chosen.
impl AgentsPanel.makeForEveryRole -> None {
    saving = True;
    made = 0;
    try {
        for r in roles {
            if not agentOf(agents, r.id) {
                seed = seedFor(r.id, r.name, steps, defaultModel);
                root spawn SaveAgent(
                    name=seed["name"],
                    role_id=r.id,
                    projects=[],
                    steps=seed["steps"],
                    event=seed["event"],
                    tools=seed["tools"],
                    access=seed["access"],
                    mode="suggest",
                    duties=seed["duties"],
                    prompt=seed["prompt"],
                    rules=seed["rules"],
                    model=defaultModel
                );
                made = made + 1;
            }
        }
        open = False;
        await load();
        toast.success(
            "Created "
                + str(made)
                + " agents. Pick a model for each, then turn them on."
        );
    } except Exception as e {
        toast.error("Could not create the agents");
    }
    saving = False;
}
