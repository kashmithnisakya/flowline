"""Canvas helpers: what a node shows, how a connection is drawn and what a flow
needs before an agent can run it. Pure data, nothing from the browser."""

import from ..constants { AGENT_TOOLS }
import from ..models { AgentView, StepView, RoleView }
import from .agents { toolKind, covers, whenText, modelReady, nodeId }

glob:pub NODE_W: float = 190.0,
     NODE_H: float = 78.0,
     CANVAS_W: float = 1760.0,
     CANVAS_H: float = 560.0,
     NODE_TYPES: list[list[str]] = [
         ["prompt", "Prompt", "Ask the model"],
         ["tool", "Tool", "Read, suggest or write"],
         ["condition", "Condition", "Branch on a result"],
         ["approval", "Approval", "A person decides"]
     ];

def:pub nodeTitle(kind: str) -> str {
    return {
        "trigger": "When",
        "prompt": "Prompt",
        "tool": "Tool",
        "condition": "If",
        "approval": "Approval"
    }[kind];
}

def:pub findNode(nodes: list[dict[str, any]], id: str) -> dict[str, any] {
    for n in nodes {
        if n["id"] == id {
            return n;
        }
    }
    return {};
}

def:pub roleName(roles: list[RoleView], id: str) -> str {
    for r in roles {
        if r.id == id {
            return r.name;
        }
    }
    return "a role";
}

# The one line a node carries.
def:pub nodeText(
    a: AgentView, n: dict[str, any], steps: list[StepView], roles: list[RoleView]
) -> str {
    kind = n["type"];
    if kind == "trigger" {
        return whenText(a.event, a.steps, steps);
    }
    if kind == "prompt" {
        said: str = n["cfg"]["text"] or "";
        return (said[:70] + "…") if len(said) > 70 else (said or "Empty prompt");
    }
    if kind == "tool" {
        return n["cfg"]["tool"] or "No tool picked";
    }
    if kind == "condition" {
        return n["cfg"]["expr"] or "No condition yet";
    }
    return "Waiting for " + roleName(roles, n["cfg"]["who"] or a.role_id);
}

# A smooth line from one node's right edge to another's left.
def:pub edgePath(f: dict[str, any], t: dict[str, any]) -> str {
    x1 = f["x"] + NODE_W;
    y1 = f["y"] + NODE_H / 2;
    x2 = t["x"];
    y2 = t["y"] + NODE_H / 2;
    k = max(50.0, abs(x2 - x1) / 2);
    return "M"
        + str(x1)
        + " "
        + str(y1)
        + " C"
        + str(x1 + k)
        + " "
        + str(y1)
        + ","
        + str(x2 - k)
        + " "
        + str(y2)
        + ","
        + str(x2)
        + " "
        + str(y2);
}

def:pub newNode(kind: str, agent: AgentView, count: int) -> dict[str, any] {
    cfg: dict[str, str] = {};
    if kind == "tool" {
        cfg = {"tool": "read_task"};
    } elif kind == "prompt" {
        cfg = {"text": ""};
    } elif kind == "condition" {
        cfg = {"expr": "findings.blocking > 0"};
    } else {
        cfg = {"who": agent.role_id};
    }
    return {
        "id": nodeId(),
        "type": kind,
        "x": 40 + (count % 7) * 40,
        "y": 300 + (count % 3) * 70,
        "cfg": cfg
    };
}

# What stops this flow from running, in words. Empty means it is ready.
def:pub flowProblems(
    a: AgentView,
    nodes: list[dict[str, any]],
    edges: list[dict[str, str]],
    models: list[list[str]]
) -> list[str] {
    out: list[str] = [];
    hasTrigger = False;
    hasPrompt = False;
    for n in nodes {
        if n["type"] == "trigger" {
            hasTrigger = True;
        }
        if n["type"] == "prompt" {
            hasPrompt = True;
        }
        if n["type"] == "tool"
            and not covers(a.access, toolKind(n["cfg"]["tool"] or "read_task")) {
            out.append(
                (n["cfg"]["tool"] or "A tool")
                    + " needs "
                    + toolKind(n["cfg"]["tool"])
                    + " access, which this agent does not have."
            );
        }
    }
    if not hasTrigger {
        out.append("Add a When node: nothing wakes this agent.");
    }
    if not hasPrompt {
        out.append("Add a Prompt node: nothing asks the model.");
    }
    if len(a.steps) == 0 and a.event == "" {
        out.append("Pick a step or an event in the When node.");
    }
    if not modelReady(a.model, models) {
        out.append("Choose a model whose provider has a key under Models and keys.");
    }
    if len(nodes) > 1 and len(edges) == 0 {
        out.append("Connect the nodes: click a round port, then another node's port.");
    }
    if not a.runs {
        out.append(
            "Only a review agent (read_pr and comment_on_pr) runs today. This flow is saved for when its kind does."
        );
    }
    return out;
}
