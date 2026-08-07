"""Workflow walkers: the org's step-graph API.

One workflow per organization, steps hanging directly off the caller's root
like every other archetype, so the one-hop ownership check keeps working
unchanged. Unlike the roadmap there is NO cycle guard here: loops are the
point. Only self-loops are refused, and duplicate transitions are deduped.
"""

import from models {
    WorkflowStep,
    WorkflowMeta,
    Task,
    StepView,
    FlowsTo,
    step_view,
    resolve,
    on_attached,
    owned
}
import from walkers.util { now_iso }
import from constants { STEP_KINDS, KIND_COLORS, KIND_STATUS, WORKFLOW_TEMPLATES }


# A step's kind IS the semantics every other part of the app reads, through
# each task's `status`. Re-point the tasks sitting on this step whenever the
# kind changes, or "done" work would keep reporting as "In Progress" to
# insights, the digest and the assistant.
def restatus_tasks(holder: Root, step: WorkflowStep) {
    landing = KIND_STATUS[step.kind] if step.kind in KIND_STATUS else "In Progress";
    target = jid(step);
    for t in [holder-->[?:Task]] {
        if t.step_id == target and t.status != landing {
            t.status = landing;
        }
    }
}


# Canvas bound in px. Positions come straight off the wire, so this is the
# only thing standing between a crafted request and a broken workspace: NaN
# and ±Infinity both fail this range test and land at the origin. A stored
# inf would serialize as the bare token `Infinity`, which JSON.parse rejects,
# so every later read of the workflow would fail in the browser with no way
# back through the UI.
glob MAX_COORD: float = 20000.0;


def safe_coord(v: float) -> float {
    if v >= 0.0 and v <= MAX_COORD {
        return v;
    }
    return 0.0;
}


# Singleton per root, like GithubConnection: first touch creates it.
def get_meta(holder: Root) -> WorkflowMeta {
    existing = [holder-->[?:WorkflowMeta]];
    if existing {
        return existing[0];
    }
    fresh = holder ++> WorkflowMeta();
    on_attached(holder, fresh);
    return fresh;
}


walker GetWorkflowMeta {
    """Read-only: a GET must not write, so an org that has never renamed
    its workflow reports the default without creating the node."""
    has reports: list[dict[str, str]] = [];

    can read with Root entry {
        existing = [here-->[?:WorkflowMeta]];
        report {"name": existing[0].name if existing else "Workflow"};
    }
}


walker RenameWorkflow {
    has name: str = "",
        reports: list[dict[str, str]] = [];

    can rename with Root entry {
        meta = get_meta(here);
        if self.name.strip() {
            meta.name = self.name.strip();
        }
        report {"name": meta.name};
    }
}


walker GetWorkflow {
    has results: list[StepView] = [],
        reports: list[list[StepView]] = [];

    can start with Root entry {
        visit [here-->[?:WorkflowStep]];
    }

    can gather with WorkflowStep entry {
        self.results.append(step_view(here));
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (s: StepView) { s.sort_order; });
        report self.results;
    }
}


walker ApplyTemplate {
    """Seed the org's workflow from one template, atomically on the server.

    Idempotent by refusal: if any step already exists the template is NOT
    applied and the existing workflow is reported instead, so a double-click
    can never produce two overlaid workflows."""
    has template_key: str = "",
        reports: list[list[StepView]] = [];

    can apply with Root entry {
        existing = [here-->[?:WorkflowStep]];
        if existing {
            views: list[StepView] = [];
            for s in existing {
                views.append(step_view(s));
            }
            views.sort(key=lambda (v: StepView) { v.sort_order; });
            report views;
            disengage;
        }
        chosen: dict[str, any] = {};
        for t in WORKFLOW_TEMPLATES {
            if t["key"] == self.template_key {
                chosen = t;
            }
        }
        if not chosen {
            report [];
            disengage;
        }
        stamp = now_iso();
        made: list[WorkflowStep] = [];
        order = 1024.0;
        for s in chosen["steps"] {
            kind = s["kind"] if s["kind"] in STEP_KINDS else "active";
            fresh = here ++> WorkflowStep(
                name=s["name"],
                kind=kind,
                color=s["color"],
                x=s["x"],
                y=s["y"],
                sort_order=order,
                created_at=stamp,
                updated_at=stamp
            );
            on_attached(here, fresh);
            made.append(fresh);
            order = order + 1024.0;
        }
        for pair in chosen["links"] {
            source = made[pair[0]];
            target = made[pair[1]];
            source +>:FlowsTo():+> target;
        }
        views: list[StepView] = [];
        for m in made {
            views.append(step_view(m));
        }
        report views;
    }
}


walker find_step {
    """Lookup base: resolve the jid once, verify org parentage, then visit.

    MoveStep and DeleteStep subclass this. SaveStep's update branch and
    Link/UnlinkTransition need Root entry (a create path, and two endpoints
    to check) so they repeat the resolve + isinstance + owned triple inline,
    exactly as SaveMilestone and LinkSteps do. However a jid is reached,
    resolution alone is NOT authorization."""
    has step_id: str = "";

    can locate with Root entry {
        target = resolve(self.step_id);
        if isinstance(target, WorkflowStep) and owned(here, target) {
            visit [target];
        }
    }
}


walker SaveStep {
    """Empty step_id creates; otherwise updates the addressed one.

    Update is partial on purpose (empty means keep), unlike UpdateTask's
    overwrite-everything: the inspector edits one field at a time and must
    not blank the others."""
    has step_id: str = "",
        name: str = "",
        kind: str = "",
        color: str = "",
        x: float = 0.0,
        y: float = 0.0,
        reports: list[StepView] = [];

    can save with Root entry {
        # Clamp before anything else: the response envelope echoes these
        # fields, so a non-finite float would 500 the request even when the
        # stored value is clean.
        self.x = safe_coord(self.x);
        self.y = safe_coord(self.y);
        stamp = now_iso();
        if self.step_id {
            target = resolve(self.step_id);
            if not isinstance(target, WorkflowStep) or not owned(here, target) {
                disengage;
            }
            if self.name.strip() {
                target.name = self.name.strip();
            }
            kind_changed = self.kind in STEP_KINDS and self.kind != target.kind;
            if self.kind in STEP_KINDS {
                target.kind = self.kind;
            }
            if kind_changed {
                restatus_tasks(here, target);
            }
            if self.color {
                target.color = self.color;
            }
            target.updated_at = stamp;
            report step_view(target);
            disengage;
        }
        if not self.name.strip() {
            disengage;
        }
        kind = self.kind if self.kind in STEP_KINDS else "active";
        color = self.color or KIND_COLORS[kind];
        peak = 0.0;
        for s in [here-->[?:WorkflowStep]] {
            if s.sort_order > peak {
                peak = s.sort_order;
            }
        }
        fresh = here ++> WorkflowStep(
            name=self.name.strip(),
            kind=kind,
            color=color,
            x=self.x,
            y=self.y,
            sort_order=peak + 1024.0,
            created_at=stamp,
            updated_at=stamp
        );
        on_attached(here, fresh);
        report step_view(fresh);
    }
}


walker MoveStep(find_step) {
    """Persist the designer position after a drag, fired on mouse-up."""
    has x: float = 0.0,
        y: float = 0.0,
        reports: list[StepView] = [];

    can move with WorkflowStep entry {
        # Clamp the walker's own fields too, not just what is stored: the
        # response envelope echoes them, and a non-finite float there is not
        # JSON-encodable, so the request would 500 even with clean data.
        self.x = safe_coord(self.x);
        self.y = safe_coord(self.y);
        here.x = self.x;
        here.y = self.y;
        here.updated_at = now_iso();
        report step_view(here);
        disengage;
    }
}


walker DeleteStep(find_step) {
    """Removes the step; every FlowsTo transition touching it dies with the
    node, and any task sitting on it falls back to its status.

    Refuses to remove the LAST start or done step: the board places
    workflow-less tasks by kind, and an org with no way in or no way out has
    a board work cannot leave."""
    has reports: list[dict[str, any]] = [];

    can remove with WorkflowStep entry {
        owners = [here<--];
        holder = owners[0];
        kind = here.kind;
        if kind == "start" or kind == "done" {
            siblings = 0;
            for s in [holder-->[?:WorkflowStep]] {
                if s.kind == kind and jid(s) != jid(here) {
                    siblings = siblings + 1;
                }
            }
            if siblings == 0 {
                report {
                    "ok": False,
                    "error": "last_of_kind",
                    "message": (
                        "This is the only "
                        + kind
                        + " step. Give another step "
                        + "that kind first, then delete this one."
                    )
                };
                disengage;
            }
        }
        gone = jid(here);
        # Tasks keep their status, so they land by kind rather than vanishing
        # into whichever column happens to be first.
        for t in [holder-->[?:Task]] {
            if t.step_id == gone {
                t.step_id = "";
            }
        }
        del here;
        report {"ok": True, "deleted": gone};
        disengage;
    }
}


walker LinkTransition {
    """Draw a transition: from_id flows to to_id.

    Both ends are owned-checked independently. Loops and branches are legal;
    a self-loop is refused and an existing duplicate reports success without
    writing a second edge."""
    has from_id: str = "",
        to_id: str = "",
        reports: list[dict[str, any]] = [];

    can link with Root entry {
        source = resolve(self.from_id);
        target = resolve(self.to_id);
        if not isinstance(source, WorkflowStep) or not owned(here, source) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if not isinstance(target, WorkflowStep) or not owned(here, target) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if jid(source) == jid(target) {
            report {
                "ok": False,
                "error": "self_link",
                "message": "A step cannot flow into itself."
            };
            disengage;
        }
        if [edge source->:FlowsTo:->target] {
            report {"ok": True, "linked": True, "duplicate": True};
            disengage;
        }
        source +>:FlowsTo():+> target;
        report {"ok": True, "linked": True, "duplicate": False};
    }
}


walker UnlinkTransition {
    has from_id: str = "",
        to_id: str = "",
        reports: list[dict[str, any]] = [];

    can unlink with Root entry {
        source = resolve(self.from_id);
        target = resolve(self.to_id);
        if not isinstance(source, WorkflowStep) or not owned(here, source) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if not isinstance(target, WorkflowStep) or not owned(here, target) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        for e in [edge source->:FlowsTo:->target] {
            del e;
        }
        report {"ok": True, "unlinked": True};
    }
}
