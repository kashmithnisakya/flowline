"""Flow line walkers: the org's step-graph API. One flow line per organization,
steps hanging off the caller's root so the one-hop ownership check works.
NO cycle guard: loops are the point; only self-loops are refused.
"""

import from models {
    WorkflowStep,
    WorkflowMeta,
    Task,
    Role,
    StepView,
    TaskView,
    FlowsTo,
    ForProject,
    step_view,
    resolve,
    on_attached,
    owned
}
import from walkers.util { now_iso }
import from constants {
    STEP_KINDS,
    KIND_COLORS,
    KIND_STATUS,
    STATUS_KIND,
    FLOW_LINE_TEMPLATES
}


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


# Where a task lands: its own step when that step still exists, else the
# first step whose kind matches its legacy status. One rule for the board,
# the counts and the per-step panel.
def landing_step(t: Task, known: list[str], first_of_kind: dict[str, str]) -> str {
    if t.step_id and t.step_id in known {
        return t.step_id;
    }
    kind = STATUS_KIND[t.status] if t.status in STATUS_KIND else "active";
    if kind in first_of_kind {
        return str(first_of_kind[kind]);
    }
    return "";
}


# Canvas bound in px. Positions come straight off the wire, so this is what
# keeps a crafted request from breaking the workspace: NaN and ±Infinity fail
# the range test and land at the origin (a stored inf would serialize as the
# bare token `Infinity`, which JSON.parse rejects on every later read).
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


walker GetFlowLineMeta {
    """Read-only: a GET must not write, so an org that has never renamed
    its flow line reports the default without creating the node."""
    has reports: list[dict[str, str]] = [];

    can read with Root entry {
        existing = [here-->[?:WorkflowMeta]];
        name = existing[0].name if existing else "";
        # "Workflow" was the default before the rename, and ApplyTemplate
        # persisted it for every templated org, so it reads as the new one.
        if not name or name == "Workflow" {
            name = "Flow line";
        }
        report {
            "name": name,
            "template_key": existing[0].template_key if existing else ""
        };
    }
}


walker RenameFlowLine {
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


walker GetFlowLine {
    """The org's steps, each carrying how much work sits on it; `project_id`
    narrows the count. Computed here so the placement rule (step first, then
    the legacy status fallback) has one implementation for board and view."""
    has project_id: str = "",
        results: list[StepView] = [],
        reports: list[list[StepView]] = [];

    can start with Root entry {
        visit [here-->[?:WorkflowStep]];
    }

    can gather with WorkflowStep entry {
        self.results.append(step_view(here));
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (s: StepView) { s.sort_order; });
        # Count into a plain map first, then stamp the views: mutating a
        # view through a dict lookup is more than the checker can follow.
        counts: dict[str, int] = {};
        known: list[str] = [];
        first_of_kind: dict[str, str] = {};
        for v in self.results {
            counts[v.id] = 0;
            known.append(v.id);
            if v.kind not in first_of_kind {
                first_of_kind[v.kind] = v.id;
            }
        }
        for t in [here-->[?:Task]] {
            if self.project_id {
                owning = [t->:ForProject:->];
                if not owning or jid(owning[0]) != self.project_id {
                    continue;
                }
            }
            landing = landing_step(t, known, first_of_kind);
            if landing {
                counts[landing] = int(counts[landing]) + 1;
            }
        }
        for v in self.results {
            v.task_count = counts[v.id];
        }
        report self.results;
    }
}


walker ListStepTasks {
    """The work sitting on one step, for the panel the flow line view opens.
    Placement reuses GetFlowLine's rule so list and count never disagree."""
    has step_id: str = "",
        project_id: str = "",
        results: list[TaskView] = [],
        reports: list[list[TaskView]] = [];

    can gather with Root entry {
        target = resolve(self.step_id);
        if not isinstance(target, WorkflowStep) or not owned(here, target) {
            report self.results;
            disengage;
        }
        wanted = jid(target);
        known: list[str] = [];
        first_of_kind: dict[str, str] = {};
        for st in [here-->[?:WorkflowStep]] {
            known.append(jid(st));
            if st.kind not in first_of_kind {
                first_of_kind[st.kind] = jid(st);
            }
        }
        for t in [here-->[?:Task]] {
            if self.project_id {
                owning = [t->:ForProject:->];
                if not owning or jid(owning[0]) != self.project_id {
                    continue;
                }
            }
            if landing_step(t, known, first_of_kind) == wanted {
                self.results.append(t.to_view());
            }
        }
        self.results.sort(key=lambda (t: TaskView) { t.sort_order; });
        report self.results;
    }
}


walker ApplyTemplate {
    """Seed the org's flow line from one template, atomically. Idempotent by
    refusal: with any step already present the existing flow line is reported
    instead, so a double-click cannot overlay two flow lines."""
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
        for t in FLOW_LINE_TEMPLATES {
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
        # Typed locals first: the checker will not subscript a nested `any`.
        raw_steps: list[dict[str, any]] = chosen["steps"];
        for s in raw_steps {
            kind = s["kind"] if s["kind"] in STEP_KINDS else "active";
            fresh = here ++> WorkflowStep(
                name=s["name"],
                kind=kind,
                color=s["color"],
                owner=str(s["owner"]) if "owner" in s else "",
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
        # Parallel list, so templates without wording keep working.
        wording: list[str] = [];
        if "link_labels" in chosen {
            wording = chosen["link_labels"];
        }
        raw_links: list[list[int]] = chosen["links"];
        for (i, pair) in enumerate(raw_links) {
            source = made[pair[0]];
            target = made[pair[1]];
            said = wording[i] if i < len(wording) else "";
            source +>:FlowsTo(label=said):+> target;
        }
        # Remember which template this was. Scratch flow lines never come
        # through here and keep the default "".
        meta = get_meta(here);
        meta.template_key = self.template_key;
        # Seed the template's roles as Role nodes, editable org data from
        # here on. Get-or-create by name, so a role the org already made
        # keeps whatever it says.
        if "roles" in chosen {
            raw_roles: list[dict[str, str]] = chosen["roles"];
            r_order = 1024.0;
            for rr in raw_roles {
                if not [here-->[?:Role, name==rr["name"]]] {
                    fresh_role = here ++> Role(
                        name=rr["name"],
                        blurb=rr["blurb"] if "blurb" in rr else "",
                        color=rr["color"] if "color" in rr else "",
                        sort_order=r_order
                    );
                    on_attached(here, fresh_role);
                }
                r_order = r_order + 1024.0;
            }
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
    MoveStep and DeleteStep subclass this; walkers needing Root entry repeat
    the resolve + isinstance + owned triple. Resolution is NOT authorization."""
    has step_id: str = "";

    can locate with Root entry {
        target = resolve(self.step_id);
        if isinstance(target, WorkflowStep) and owned(here, target) {
            visit [target];
        }
    }
}


walker SaveStep {
    """Empty step_id creates; otherwise updates the addressed one. Update is
    partial on purpose (empty means keep): the inspector edits one field at a
    time and must not blank the others."""
    has step_id: str = "",
        name: str = "",
        kind: str = "",
        color: str = "",
        # Empty means "keep", like every field here; a space clears it.
        owner: str = "",
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
            if self.owner {
                target.owner = self.owner.strip();
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
            owner=self.owner.strip(),
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
    """Removes the step; its transitions die with it and any task on it falls
    back to its status. Refuses to remove the LAST start or done step: an org
    with no way in or out has a board work cannot leave."""
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
                        "This is the only " + kind + " step. Give another step "
                        "that kind first, then delete this one."
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


walker DeleteFlowLine {
    """Removes every step and transition so the flow line can be designed again.
    Walks the caller's own root (no jid input, nothing to owned()-check).
    Tasks fall back to their status as after DeleteStep; name and roles stay;
    the template marker is cleared so a scratch redo does not report it."""
    has reports: list[dict[str, any]] = [];

    can wipe with Root entry {
        steps = [here-->[?:WorkflowStep]];
        gone: list[str] = [];
        for s in steps {
            gone.append(jid(s));
        }
        for t in [here-->[?:Task]] {
            if t.step_id and t.step_id in gone {
                t.step_id = "";
            }
        }
        for s in steps {
            del s;
        }
        for meta in [here-->[?:WorkflowMeta]] {
            meta.template_key = "";
        }
        report {"ok": True, "deleted": len(gone)};
    }
}


walker LinkTransition {
    """Draw a transition from_id -> to_id, both ends owned-checked. Loops and
    branches are legal; a self-loop is refused and a duplicate reports success."""
    has from_id: str = "",
        to_id: str = "",
        # What has to be true to cross. Optional.
        label: str = "",
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
        # Re-drawing an arrow is how its label gets edited.
        existing = [edge source->:FlowsTo:->target];
        if existing {
            if self.label.strip() {
                for e in existing {
                    e.label = self.label.strip();
                }
            }
            report {"ok": True, "linked": True, "duplicate": True};
            disengage;
        }
        source +>:FlowsTo(label=self.label.strip()):+> target;
        report {"ok": True, "linked": True, "duplicate": False};
    }
}


walker LabelTransition {
    """Set or clear what has to be true to cross an existing transition. Unlike
    LinkTransition, an empty label here means CLEAR, the only way to take the
    wording off an arrow without deleting it."""
    has from_id: str = "",
        to_id: str = "",
        label: str = "",
        reports: list[dict[str, any]] = [];

    can relabel with Root entry {
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
        said = self.label.strip();
        found = False;
        for e in [edge source->:FlowsTo:->target] {
            e.label = said;
            found = True;
        }
        if not found {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        report {"ok": True, "label": said};
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
