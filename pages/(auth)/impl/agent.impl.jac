"""Implementations for an agent's canvas."""

impl AgentPage.load -> None {
    w: any = window;
    params: any = new(w.URLSearchParams, w.location.search);
    wanted = str(params.get("id") or "");
    try {
        shared = await loadWorkspace();
        read = root spawn ListAgents();
        keyed = root spawn ListAiKeys();
        found: AgentView | None = None;
        for a in (read.reports[0] if read.reports else []) {
            if a.id == wanted {
                found = a;
            }
        }
        roles = shared["roles"];
        steps = shared["steps"];
        keys: any = keyed.reports[0] if keyed.reports else None;
        models = keys.models if keys else [];
        if found is None {
            missing = True;
        } else {
            agent = found;
            drawn = found.canvas;
            if drawn["nodes"] and len(drawn["nodes"]) > 0 {
                nodes = drawn["nodes"];
                edges = drawn["edges"] or [];
            } else {
                start = startCanvas(found);
                nodes = start["nodes"];
                edges = start["edges"];
                dirty = True;
            }
        }
    } except Exception as e {
        toast.error("Could not load that agent");
    }
    loading = False;
}

impl AgentPage.moveNode(id: str, x: float, y: float) -> None {
    moved: list[dict[str, any]] = [];
    for n in nodes {
        if n["id"] == id {
            moved.append({** n, "x": x, "y": y});
        } else {
            moved.append(n);
        }
    }
    nodes = moved;
}

impl AgentPage.pickNode(id: str) -> None {
    sel = id;
    selEdge = "";
}

impl AgentPage.addNode(kind: str) -> None {
    if agent is None {
        return;
    }
    made = newNode(kind, agent, len(nodes));
    nodes = nodes + [made];
    sel = made["id"];
    selEdge = "";
    dirty = True;
}

impl AgentPage.setCfg(key: str, value: str) -> None {
    changed: list[dict[str, any]] = [];
    for n in nodes {
        if n["id"] == sel {
            cfg = {** n["cfg"]};
            cfg[key] = value;
            changed.append({** n, "cfg": cfg});
        } else {
            changed.append(n);
        }
    }
    nodes = changed;
    dirty = True;
}

impl AgentPage.connectFrom(id: str) -> None {
    link = "" if link == id else id;
    if link != "" {
        toast("Now click the round port on the left of the next node");
    }
}

impl AgentPage.connectTo(id: str) -> None {
    if link == "" or link == id {
        return;
    }
    for e in edges {
        if e["from"] == link and e["to"] == id {
            link = "";
            return;
        }
    }
    edges = edges + [{"id": nodeId(), "from": link, "to": id}];
    link = "";
    dirty = True;
}

impl AgentPage.removeNode -> None {
    keptNodes: list[dict[str, any]] = [];
    keptEdges: list[dict[str, str]] = [];
    for n in nodes {
        if n["id"] != sel {
            keptNodes.append(n);
        }
    }
    for e in edges {
        if e["from"] != sel and e["to"] != sel {
            keptEdges.append(e);
        }
    }
    nodes = keptNodes;
    edges = keptEdges;
    sel = "";
    dirty = True;
}

impl AgentPage.removeEdge -> None {
    kept: list[dict[str, str]] = [];
    for e in edges {
        if e["id"] != selEdge {
            kept.append(e);
        }
    }
    edges = kept;
    selEdge = "";
    dirty = True;
}

impl AgentPage.resetToSetup -> None {
    if agent is None {
        return;
    }
    start = startCanvas(agent);
    nodes = start["nodes"];
    edges = start["edges"];
    sel = "";
    selEdge = "";
    dirty = True;
    toast("The canvas is rebuilt from the agent's setup. Save it to keep it.");
}

impl AgentPage.check -> None {
    if agent is None {
        return;
    }
    problems = flowProblems(agent, nodes, edges, models);
    checked = True;
}

impl AgentPage.toggleStep(id: str) -> None {
    if agent is None {
        return;
    }
    kept: list[str] = [];
    present = False;
    for s in agent.steps {
        if s == id {
            present = True;
        } else {
            kept.append(s);
        }
    }
    if not present {
        kept.append(id);
    }
    saveSetup(kept, "");
}

# The When node edits the agent's own setup, so it saves the agent.
impl AgentPage.saveSetup(wanted: list[str], event: str) -> None {
    if agent is None {
        return;
    }
    keep = agent;
    stepsNow = wanted if (len(wanted) > 0 or event == "") else [];
    try {
        result = root spawn SaveAgent(
            agent_id=keep.id,
            name=keep.name,
            role_id=keep.role_id,
            projects=keep.projects,
            steps=stepsNow if event == "" else [],
            event=event,
            tools=keep.tools,
            access=keep.access,
            mode=keep.mode,
            duties=keep.duties,
            prompt=keep.prompt,
            rules=keep.rules,
            model=keep.model
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            agent = answer["agent"];
            forgetWorkspace();
        } else {
            toast.error(answer["message"] if answer else "Could not save that");
        }
    } except Exception as e {
        toast.error("Could not save that");
    }
}

impl AgentPage.saveCanvas -> None {
    if agent is None or saving {
        return;
    }
    saving = True;
    try {
        result = root spawn SaveAgentCanvas(
            agent_id=agent.id, canvas={"nodes": nodes, "edges": edges}
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            agent = answer["agent"];
            dirty = False;
            toast.success("Flow saved");
        } else {
            toast.error(answer["message"] if answer else "Could not save the flow");
        }
    } except Exception as e {
        toast.error("Could not save the flow");
    }
    saving = False;
}
