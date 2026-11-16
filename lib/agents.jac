"""Agent setup on the client: a blank draft, what a responsibility template fills
in, the status a row shows and the node graph an agent starts on its canvas.
Pure data, no walker calls and nothing from the browser."""

import from ..constants { AGENT_TOOLS, AGENT_DUTIES, AGENT_EVENTS }
import from ..models { AgentView, StepView }

def:pub blankAgent(model: str) -> dict[str, any] {
    return {
        "id": "",
        "name": "",
        "role_id": "",
        "projects": [],
        "steps": [],
        "event": "",
        "tools": [],
        "access": {"suggest": True, "write": False},
        "mode": "suggest",
        "duties": [],
        "prompt": "",
        "rules": "",
        "model": model
    };
}

# A saved agent as an editable draft.
def:pub draftOf(a: AgentView) -> dict[str, any] {
    return {
        "id": a.id,
        "name": a.name,
        "role_id": a.role_id,
        "projects": a.projects,
        "steps": a.steps,
        "event": a.event,
        "tools": a.tools,
        "access": {
            "suggest": bool(a.access["suggest"]),
            "write": bool(a.access["write"])
        },
        "mode": a.mode,
        "duties": a.duties,
        "prompt": a.prompt,
        "rules": a.rules,
        "model": a.model
    };
}

def:pub toolKind(key: str) -> str {
    for t in AGENT_TOOLS {
        if t["key"] == key {
            return t["kind"];
        }
    }
    return "read";
}

# Does this access cover tools of this kind?
def:pub covers(access: dict[str, bool], kind: str) -> bool {
    if kind == "read" {
        return True;
    }
    return bool(access[kind]);
}

# Does a role already have an agent?
def:pub agentOf(agents: list[AgentView], roleId: str) -> bool {
    for a in agents {
        if a.role_id == roleId {
            return True;
        }
    }
    return False;
}

# The responsibilities a role usually takes, by its name. A role this does not
# know starts with none.
def:pub dutiesFor(roleName: str) -> list[str] {
    low = roleName.lower();
    if "engineer" in low or "developer" in low {
        return ["review", "notes"];
    }
    if "qa" in low or "test" in low {
        return ["testplan"];
    }
    if "product" in low or "owner" in low {
        return ["triage", "watch"];
    }
    if "release" in low {
        return ["notes", "watch"];
    }
    if "design" in low {
        return ["writer"];
    }
    return [];
}

def:pub dutyBy(key: str) -> dict[str, any] {
    for d in AGENT_DUTIES {
        if d["key"] == key {
            return d;
        }
    }
    return AGENT_DUTIES[0];
}

# The earliest step of a kind on this flow line, or "".
def:pub stepOfKind(steps: list[StepView], kind: str) -> str {
    found = "";
    at = 0.0;
    for s in steps {
        if s.kind == kind and (found == "" or s.sort_order < at) {
            found = s.id;
            at = s.sort_order;
        }
    }
    return found;
}

# The draft after its responsibilities changed: their tools and prompts are
# gathered, the access they need is switched on, and an empty trigger takes the
# first one's usual step or event.
def:pub applyDuties(draft: dict[str, any], steps: list[StepView]) -> dict[str, any] {
    out = {** draft};
    tools: list[str] = [];
    prompts: list[str] = [];
    for k in draft["duties"] {
        d = dutyBy(k);
        for t in d["tools"] {
            if t not in tools {
                tools.append(t);
            }
        }
        prompts.append(d["prompt"]);
    }
    access = {
        "suggest": bool(draft["access"]["suggest"]),
        "write": bool(draft["access"]["write"])
    };
    for t in tools {
        kind = toolKind(t);
        if kind != "read" {
            access[kind] = True;
        }
    }
    out["tools"] = tools;
    out["access"] = access;
    out["prompt"] = " ".join(prompts);
    if len(draft["duties"]) > 0 and len(draft["steps"]) == 0 and draft["event"] == "" {
        first = dutyBy(draft["duties"][0]);
        sid = stepOfKind(steps, first["kind"]);
        if sid {
            out["steps"] = [sid];
        } elif first["event"] {
            out["event"] = first["event"];
        }
    }
    return out;
}

# The draft with one access kind switched, and any tool it no longer covers dropped.
def:pub withAccess(draft: dict[str, any], kind: str, on: bool) -> dict[str, any] {
    access = {
        "suggest": bool(draft["access"]["suggest"]),
        "write": bool(draft["access"]["write"])
    };
    access[kind] = on;
    kept: list[str] = [];
    for t in draft["tools"] {
        if covers(access, toolKind(t)) {
            kept.append(t);
        }
    }
    out = {** draft};
    out["access"] = access;
    out["tools"] = kept;
    return out;
}

# A starting agent for a role, from the responsibilities that role usually takes.
def:pub seedFor(
    roleId: str, roleName: str, steps: list[StepView], model: str
) -> dict[str, any] {
    seed = blankAgent(model);
    seed["role_id"] = roleId;
    seed["name"] = roleName + " agent";
    seed["duties"] = dutiesFor(roleName);
    seed["rules"] = "Ask a person when unsure.";
    return applyDuties(seed, steps);
}

def:pub eventWord(key: str) -> str {
    for e in AGENT_EVENTS {
        if e[0] == key {
            return e[1];
        }
    }
    return "";
}

def:pub stepName(steps: list[StepView], sid: str) -> str {
    for s in steps {
        if s.id == sid {
            return s.name;
        }
    }
    return "";
}

# When an agent wakes, in words.
def:pub whenText(event: str, stepIds: list[str], steps: list[StepView]) -> str {
    if event {
        return eventWord(event);
    }
    names: list[str] = [];
    for sid in stepIds {
        n = stepName(steps, sid);
        if n {
            names.append(n);
        }
    }
    return ("Lands on " + ", ".join(names)) if len(names) > 0 else "No trigger yet";
}

def:pub modelReady(model: str, models: list[list[str]]) -> bool {
    for m in models {
        if m[0] == model {
            return True;
        }
    }
    return False;
}

def:pub modelLabel(model: str, models: list[list[str]]) -> str {
    if not model {
        return "No model chosen";
    }
    for m in models {
        if m[0] == model {
            return m[1];
        }
    }
    return model.replace(":", " / ");
}

# [label, tone] for a row: what an agent needs, or whether it is on.
def:pub statusOf(a: AgentView, models: list[list[str]]) -> list[str] {
    if not a.model {
        return ["Needs a model", "warn"];
    }
    if not modelReady(a.model, models) {
        return ["Needs an API key", "warn"];
    }
    if a.enabled and not a.runs {
        return ["On, runs soon", "muted"];
    }
    return ["On", "ok"] if a.enabled else ["Off", "muted"];
}

def:pub nodeId -> str {
    return "n" + str(Math.floor(Math.random() * 100000000));
}

# The graph an agent starts on its canvas: when, what it reads, the prompt,
# an approval when it only suggests, then what it does.
def:pub startCanvas(a: AgentView) -> dict[str, any] {
    nodes: list[dict[str, any]] = [];
    edges: list[dict[str, str]] = [];
    last = "";
    x = 30;
    reads: list[str] = [];
    acts: list[str] = [];
    for t in a.tools {
        if toolKind(t) == "read" {
            reads.append(t);
        } else {
            acts.append(t);
        }
    }
    plan: list[dict[str, any]] = [{"type": "trigger", "cfg": {}}];
    for t in reads {
        plan.append({"type": "tool", "cfg": {"tool": t}});
    }
    plan.append({"type": "prompt", "cfg": {"text": a.prompt}});
    if a.mode == "suggest" and len(acts) > 0 {
        plan.append({"type": "approval", "cfg": {"who": a.role_id}});
    }
    for t in acts {
        plan.append({"type": "tool", "cfg": {"tool": t}});
    }
    for p in plan {
        nid = nodeId();
        nodes.append({"id": nid, "type": p["type"], "x": x, "y": 70, "cfg": p["cfg"]});
        if last {
            edges.append({"id": nodeId(), "from": last, "to": nid});
        }
        last = nid;
        x = x + 230;
    }
    return {"nodes": nodes, "edges": edges};
}
