"""Agent walkers: an AI teammate that plays one role. An agent hangs under the
Agents box, so every jid-addressed write resolves the row and checks owned()
first. Setup (when, tools, access, prompt, model) and the drawn canvas are
saved here; the runner (runner.jac) is what runs an agent, and only a review
agent (read_pr and comment_on_pr) runs yet."""

import from models {
    Agent,
    Agents,
    AgentView,
    Role,
    Project,
    WorkflowStep,
    agent_view,
    agents_box,
    resolve,
    owned,
    on_attached
}
import from constants {
    AGENT_TOOLS,
    AGENT_EVENTS,
    AGENT_MODES,
    AGENT_NODE_TYPES,
    AGENT_SETUP,
    AI_PROVIDERS
}
import from services.agents.keys { refusal, read_keys, provider_info }
import from services.util { now_iso }

def tool_kind(key: str) -> str {
    for t in AGENT_TOOLS {
        if t["key"] == key {
            return t["kind"];
        }
    }
    return "";
}


def kept_ids(holder: Root, ids: list[str], steps: bool) -> list[str] {
    out: list[str] = [];
    for rid in ids {
        target = resolve(rid);
        fits = isinstance(target, WorkflowStep)
            if steps
            else isinstance(target, Project);
        if fits and owned(holder, target) and jid(target) not in out {
            out.append(jid(target));
        }
    }
    return out;
}


# Why this setup cannot be saved, as a refusal, or {} when it can. `f` holds
# the walker's fields: name, role_id, event, tools, access, mode, prompt, rules
# and model.
def setup_problem(holder: Root, f: dict[str, any]) -> dict[str, any] {
    name: str = f["name"];
    event: str = f["event"];
    tools: list[str] = f["tools"];
    access: dict[str, bool] = f["access"];
    model: str = f["model"];
    if not name.strip() or len(name.strip()) > AGENT_SETUP["name"] {
        return refusal("bad_name", "Give the agent a name of up to 80 characters.");
    }
    role = resolve(f["role_id"]);
    if not isinstance(role, Role) or not owned(holder, role) {
        return refusal("bad_role", "Pick one of the workspace's roles.");
    }
    if event not in [e[0] for e in AGENT_EVENTS] {
        return refusal("bad_event", "That event is not one an agent can wake on.");
    }
    if f["mode"] not in AGENT_MODES {
        return refusal("bad_mode", "Mode is suggest or apply.");
    }
    if len(f["prompt"]) > AGENT_SETUP["prompt"]
        or len(f["rules"]) > AGENT_SETUP["rules"] {
        return refusal("too_long", "The prompt or the rules are too long.");
    }
    seen: list[str] = [];
    for t in tools {
        kind = tool_kind(t);
        if not kind or t in seen {
            return refusal("bad_tool", "Unknown or repeated tool " + t + ".");
        }
        seen.append(t);
        if kind != "read" and not access.get(kind, False) {
            return refusal("no_access", t + " needs " + kind + " access.");
        }
    }
    if model {
        pk = model.split(":", 1)[0];
        name_ = model.split(":", 1)[1] if ":" in model else "";
        info = provider_info(pk);
        if not info or not name_ or len(name_) > 100 {
            return refusal("bad_model", "Pick a model from the list.");
        }
        if pk != "custom" and name_ not in info["models"] {
            return refusal("bad_model", "Pick a model from the list.");
        }
    }
    return {};
}


# Is this agent's model one a connected provider offers right now?
def model_ready(holder: Root, model: str) -> bool {
    return model in [m[0] for m in read_keys(holder).models];
}


# Oldest first; the jid breaks a tie so the order never changes between reads.
def oldest_first(a: Agent) -> str {
    return a.created_at + jid(a);
}


walker:protect ListAgents {
    """Every agent of the workspace, oldest first."""
    has reports: list[list[AgentView]] = [];

    can start with Root entry {
        visit [here-->[?:Agents]] else {
            report [];
        }
    }

    can read with Agents entry {
        rows = [a for a in [here-->[?:Agent]]];
        rows.sort(key=oldest_first);
        report [agent_view(a) for a in rows];
        disengage;
    }
}

walker:protect SaveAgent {
    """Create or update an agent. An empty agent_id creates one. Setup only:
    whether it is on is SetAgentEnabled's, and the canvas is SaveAgentCanvas's."""
    has agent_id: str = "",
        name: str = "",
        role_id: str = "",
        projects: list[str] = [],
        steps: list[str] = [],
        event: str = "",
        tools: list[str] = [],
        access: dict[str, bool] = {},
        mode: str = "suggest",
        duties: list[str] = [],
        prompt: str = "",
        rules: str = "",
        model: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        problem = setup_problem(
            here,
            {
                "name": self.name,
                "role_id": self.role_id,
                "event": self.event,
                "tools": self.tools,
                "access": self.access,
                "mode": self.mode,
                "prompt": self.prompt,
                "rules": self.rules,
                "model": self.model
            }
        );
        if problem {
            report problem;
            disengage;
        }
        if not self.agent_id {
            if len([here-->[?:Agents]-->[?:Agent]]) >= AGENT_SETUP["max_agents"] {
                report refusal("too_many", "A workspace holds up to 30 agents.");
                disengage;
            }
            visit agents_box(here);
            return;
        }
        target = resolve(self.agent_id);
        if isinstance(target, Agent) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown agent.");
        }
    }

    can create with Agents entry {
        made = here ++> Agent(name=self.name.strip(), created_at=now_iso());
        on_attached(root, made);
        self.apply(root, made);
        report {"ok": True, "agent": agent_view(made)};
        disengage;
    }

    can update with Agent entry {
        self.apply(root, here);
        report {"ok": True, "agent": agent_view(here)};
        disengage;
    }

    def apply(holder: Root, a: Agent) {
        a.name = self.name.strip();
        a.role_id = self.role_id;
        a.projects = kept_ids(holder, self.projects, False);
        a.steps = kept_ids(holder, self.steps, True);
        a.event = self.event;
        a.tools = list(self.tools);
        a.access = {
            "suggest": bool(self.access.get("suggest", False)),
            "write": bool(self.access.get("write", False))
        };
        a.mode = self.mode;
        a.duties = [
            d
            for d in self.duties
            if len(d) <= 40
        ][:12];
        a.prompt = self.prompt.strip();
        a.rules = self.rules.strip();
        a.model = self.model;
        if a.enabled and not model_ready(holder, a.model) {
            a.enabled = False;
        }
        a.updated_at = now_iso();
    }
}

walker:protect SetAgentEnabled {
    """Switch an agent on or off. On needs a model whose provider has a key."""
    has agent_id: str = "",
        enabled: bool = False,
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.agent_id);
        if isinstance(target, Agent) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown agent.");
        }
    }

    can flip with Agent entry {
        if self.enabled and not model_ready(root, here.model) {
            report refusal(
                "no_model",
                "Choose a model whose provider has a key under Models and keys first."
            );
            disengage;
        }
        here.enabled = self.enabled;
        here.updated_at = now_iso();
        report {"ok": True, "agent": agent_view(here)};
        disengage;
    }
}

def clean_canvas(raw: dict[str, any]) -> dict[str, any] {
    nodes: list[dict[str, any]] = [];
    ids: list[str] = [];
    for n in list(raw.get("nodes") or [])[:AGENT_SETUP["nodes"]] {
        if not isinstance(n, dict) {
            continue;
        }
        nid = str(n.get("id") or "")[:40];
        kind = str(n.get("type") or "");
        if not nid or nid in ids or kind not in AGENT_NODE_TYPES {
            continue;
        }
        cfg: dict[str, any] = {};
        given = n.get("cfg");
        if isinstance(given, dict) {
            cfg = given;
        }
        keep: dict[str, str] = {};
        tool = str(cfg.get("tool") or "");
        if tool and tool_kind(tool) {
            keep["tool"] = tool;
        }
        for field in ["text", "expr", "who"] {
            if field in cfg {
                keep[field] = str(cfg[field])[:AGENT_SETUP["node_text"]];
            }
        }
        ids.append(nid);
        nodes.append(
            {
                "id": nid,
                "type": kind,
                "x": max(0, min(4000, int(n.get("x") or 0))),
                "y": max(0, min(4000, int(n.get("y") or 0))),
                "cfg": keep
            }
        );
    }
    edges: list[dict[str, str]] = [];
    for e in list(raw.get("edges") or [])[:AGENT_SETUP["edges"]] {
        if not isinstance(e, dict) {
            continue;
        }
        src = str(e.get("from") or "");
        dst = str(e.get("to") or "");
        if src in ids and dst in ids and src != dst {
            edges.append(
                {"id": str(e.get("id") or src + ">" + dst)[:60], "from": src, "to": dst}
            );
        }
    }
    return {"nodes": nodes, "edges": edges};
}


walker:protect SaveAgentCanvas {
    """Save the flow drawn for an agent. The canvas is its design; the runner
    follows the agent's setup, not this graph, so nothing here widens access."""
    has agent_id: str = "",
        canvas: dict[str, any] = {},
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.agent_id);
        if isinstance(target, Agent) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown agent.");
        }
    }

    can save with Agent entry {
        here.canvas = clean_canvas(self.canvas);
        here.updated_at = now_iso();
        report {"ok": True, "agent": agent_view(here)};
        disengage;
    }
}

walker:protect DeleteAgent {
    """Delete an agent. Its past runs stay, as history."""
    has agent_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.agent_id);
        if isinstance(target, Agent) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown agent.");
        }
    }

    can remove with Agent entry {
        gone = jid(here);
        del here;
        report {"ok": True, "deleted": gone};
        disengage;
    }
}
