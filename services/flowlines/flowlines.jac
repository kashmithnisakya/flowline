"""Flow line walkers: the org's step-graph API. One flow line per organization:
the WorkflowSteps box under the caller's root holds the steps and the flow
line's own name and template key. A walker visits the box or the addressed
step and works there; the traversal from the caller's root is the isolation.
NO cycle guard: loops are the point; only self-loops are refused.
"""

import from jaclang.lib.effects { effects }
import from models {
    WorkflowStep,
    WorkflowSteps,
    Task,
    Role,
    StepView,
    TaskPage,
    Project,
    hydrate_rows,
    step_view,
    resolve,
    on_attached,
    owned,
    default_project,
    project_working,
    tasks_on_step,
    tasks_on_steps,
    mismatched_on_step,
    steps_of,
    roles_box,
    steps_box
}
import from services.util { now_iso, page_bounds, done_cutoff, ensure_tallies }
import from constants {
    STEP_KINDS,
    KIND_COLORS,
    KIND_STATUS,
    STATUS_KIND,
    CARRY_KINDS,
    TRANSITION_TRIGGERS,
    FLOW_LINE_TEMPLATES
}


# A step's kind IS the semantics every other part of the app reads, through
# each task's `status`. Re-point the tasks sitting on this step whenever the
# kind changes, or "done" work would keep reporting as "In Progress" to
# insights, the digest and the assistant. Only the mismatched rows load.
def restatus_tasks(holder: Root, step: WorkflowStep) {
    landing = KIND_STATUS[step.kind] if step.kind in KIND_STATUS else "In Progress";
    stamp = now_iso();
    for t in mismatched_on_step(holder, jid(step), landing) {
        t.set_status(landing, stamp);
    }
}


# The tasks the flow line counts and lists: one project's working set (open
# plus Done reached in the last `done_days`), the board's scope. An empty
# `project_id` is the default project, as on the board; a foreign or
# unknown id is nothing.
def flow_pool(holder: Root, project_id: str, done_days: int) -> list[Task] {
    cutoff = done_cutoff(done_days);
    if not project_id {
        first = default_project(holder);
        return project_working(first, cutoff) if first is not None else [];
    }
    p = resolve(project_id);
    if not isinstance(p, Project) or not owned(holder, p) {
        return [];
    }
    return project_working(p, cutoff);
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


# One stored transition. A trigger outside TRANSITION_TRIGGERS is none, and
# only a "label" trigger keeps a match: the others need nothing named.
def transition(
    to: str, label: str, carries: str, trigger: str, wanted: str
) -> dict[str, str] {
    fired = trigger.strip() if trigger.strip() in TRANSITION_TRIGGERS else "";
    return {
        "to": to,
        "label": label.strip(),
        "carries": carries.strip() if carries.strip() in CARRY_KINDS else "",
        "trigger": fired,
        "trigger_label": wanted.strip() if fired == "label" else ""
    };
}


@effects(reads=["WorkflowSteps"], writes=[])
def read_flow_line_meta(box: WorkflowSteps) -> dict[str, str] {
    return {"name": box.name, "template_key": box.template_key};
}


walker GetFlowLineMeta {
    """Read-only: a GET must not write, so a workspace with no box yet
    reports the defaults without creating one."""
    has reports: list[dict[str, str]] = [];

    can start with Root entry {
        visit [here-->[?:WorkflowSteps]] else {
            report {"name": "Flow line", "template_key": ""};
        }
    }

    can read with WorkflowSteps entry {
        report read_flow_line_meta(here);
    }
}


walker RenameFlowLine {
    has name: str = "",
        reports: list[dict[str, str]] = [];

    can start with Root entry {
        visit steps_box(here);
    }

    can rename with WorkflowSteps entry {
        if self.name.strip() {
            here.name = self.name.strip();
        }
        report {"name": here.name};
    }
}


# How many titles a step carries beside its count: what a node shows at
# the flow line's closest zoom.
glob STEP_TITLES: int = 2;


# The steps in order, each counting the tasks it holds when `with_counts`
# and carrying the first STEP_TITLES titles in the panel's order. Declared
# a pure read (the stamps are on a view, not a node) so the browser caches
# GetFlowLine; a write anywhere invalidates it.
@effects(reads=["WorkflowStep", "Task"], writes=[])
def read_flow_line(
    box: WorkflowSteps, holder: Root, project_id: str, with_counts: bool, done_days: int
) -> list[StepView] {
    views: list[StepView] = [];
    line_steps = [box-->[?:WorkflowStep]];
    for st in line_steps {
        views.append(step_view(st, line_steps));
    }
    views.sort(key=lambda (s: StepView) { s.sort_order; });
    if not with_counts {
        return views;
    }
    # The one-time tally fill lives here, not in the walker: a call the
    # effect pass cannot classify would cost the reader its cache verdict.
    ensure_tallies(holder);
    # Count into plain maps first, then stamp the views: mutating a
    # view through a dict lookup is more than the checker can follow.
    counts: dict[str, int] = {};
    titles: dict[str, list[str]] = {};
    known: list[str] = [];
    first_of_kind: dict[str, str] = {};
    for v in views {
        counts[v.id] = 0;
        titles[v.id] = [];
        known.append(v.id);
        if v.kind not in first_of_kind {
            first_of_kind[v.kind] = v.id;
        }
    }
    # The working set is loaded once for the counts; in the panel's order
    # (jid, then sort_order, as ListStepTasks pages it) the first titles
    # per landing step are the panel's first rows, with no query per step.
    pool = flow_pool(holder, project_id, done_days);
    pool.sort(key=lambda (t: Task) { jid(t); });
    pool.sort(key=lambda (t: Task) { t.sort_order; });
    for t in pool {
        landing = landing_step(t, known, first_of_kind);
        if landing {
            counts[landing] = int(counts[landing]) + 1;
            held = titles[landing];
            if len(held) < STEP_TITLES {
                held.append(t.title);
            }
        }
    }
    for v in views {
        v.task_count = counts[v.id];
        v.task_titles = titles[v.id];
    }
    return views;
}


walker GetFlowLine {
    """The org's steps, each carrying how much work sits on it; `project_id`
    narrows the count. Computed here so the placement rule (step first, then
    the legacy status fallback) has one implementation for board and view.
    The count is over the working set (`done_days`, as on the board), so
    only that is loaded. `with_counts=False` skips the walk: the board
    counts the rows it already holds, so its 60 s poll need not pay for it."""
    has project_id: str = "",
        with_counts: bool = True,
        done_days: int = 7,
        reports: list[list[StepView]] = [];

    can start with Root entry {
        visit [here-->[?:WorkflowSteps]] else {
            report [];
        }
    }

    can gather with WorkflowSteps entry {
        report read_flow_line(
            here, root, self.project_id, self.with_counts, self.done_days
        );
    }
}


walker ListStepTasks {
    """One page of the work sitting on one step, for the panel the flow line
    view opens. Placement reuses GetFlowLine's rule over the same working
    set (`done_days`) so list and count never disagree; the walk touches
    node fields only and the page alone is hydrated. `total` is the whole
    step, so the header can keep counting."""
    has step_id: str = "",
        project_id: str = "",
        done_days: int = 7,
        page: int = 1,
        page_size: int = 0,
        reports: list[TaskPage] = [];

    can start with Root entry {
        ensure_tallies(here);
        target = resolve(self.step_id);
        if isinstance(target, WorkflowStep) and owned(here, target) {
            visit [target];
        } else {
            (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
            report TaskPage(rows=[], page=p, page_size=size, has_more=False, total=0);
        }
    }

    can gather with WorkflowStep entry {
        (p, size, start, end) = page_bounds(self.page, self.page_size, 50, 500);
        wanted = jid(here);
        known: list[str] = [];
        first_of_kind: dict[str, str] = {};
        for st in steps_of(root) {
            known.append(jid(st));
            if st.kind not in first_of_kind {
                first_of_kind[st.kind] = jid(st);
            }
        }
        picked: list[Task] = [];
        for t in flow_pool(root, self.project_id, self.done_days) {
            if landing_step(t, known, first_of_kind) != wanted {
                continue;
            }
            picked.append(t);
        }
        # jid first, then the real key: sorts are stable, so equal
        # sort_orders keep one order across pages instead of swapping.
        picked.sort(key=lambda (t: Task) { jid(t); });
        picked.sort(key=lambda (t: Task) { t.sort_order; });
        report TaskPage(
            rows=hydrate_rows(root, picked[start:end]),
            page=p,
            page_size=size,
            has_more=len(picked) > end,
            total=len(picked)
        );
        disengage;
    }
}


walker ApplyTemplate {
    """Seed the org's flow line from one template, atomically. Idempotent by
    refusal: with any step already present the existing flow line is reported
    instead, so a double-click cannot overlay two flow lines."""
    has template_key: str = "",
        reports: list[list[StepView]] = [];

    can start with Root entry {
        visit steps_box(here);
    }

    can apply with WorkflowSteps entry {
        existing = [here-->[?:WorkflowStep]];
        if existing {
            views: list[StepView] = [];
            for s in existing {
                views.append(step_view(s, existing));
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
                blurb=str(s["blurb"]) if "blurb" in s else "",
                needs_due_date=bool(s["needs_due_date"])
                    if "needs_due_date" in s
                    else False,
                needs_pr=bool(s["needs_pr"]) if "needs_pr" in s else False,
                x=s["x"],
                y=s["y"],
                sort_order=order,
                created_at=stamp,
                updated_at=stamp
            );
            on_attached(root, fresh);
            made.append(fresh);
            order = order + 1024.0;
        }
        # Parallel lists, so templates without wording or tags keep working.
        wording: list[str] = [];
        if "link_labels" in chosen {
            wording = chosen["link_labels"];
        }
        cargo: list[str] = [];
        if "link_carries" in chosen {
            cargo = chosen["link_carries"];
        }
        fires: list[str] = [];
        if "link_triggers" in chosen {
            fires = chosen["link_triggers"];
        }
        matches: list[str] = [];
        if "link_matches" in chosen {
            matches = chosen["link_matches"];
        }
        raw_links: list[list[int]] = chosen["links"];
        for (i, pair) in enumerate(raw_links) {
            source = made[pair[0]];
            target = made[pair[1]];
            source.transitions = source.transitions
                + [
                    transition(
                        jid(target),
                        wording[i] if i < len(wording) else "",
                        cargo[i] if i < len(cargo) else "",
                        fires[i] if i < len(fires) else "",
                        matches[i] if i < len(matches) else ""
                    )
                ];
        }
        # Remember which template this was. Scratch flow lines never come
        # through here and keep the default "".
        here.template_key = self.template_key;
        # Seed the template's roles as Role nodes, editable org data from
        # here on. Get-or-create by name, so a role the org already made
        # keeps whatever it says.
        if "roles" in chosen {
            raw_roles: list[dict[str, str]] = chosen["roles"];
            rbox = roles_box(root);
            held = [r.name for r in [rbox-->[?:Role]]];
            r_order = 1024.0;
            for rr in raw_roles {
                if rr["name"] not in held {
                    fresh_role = rbox ++> Role(
                        name=rr["name"],
                        blurb=rr["blurb"] if "blurb" in rr else "",
                        color=rr["color"] if "color" in rr else "",
                        sort_order=r_order
                    );
                    on_attached(root, fresh_role);
                    held.append(rr["name"]);
                }
                r_order = r_order + 1024.0;
            }
        }
        views: list[StepView] = [];
        for m in made {
            views.append(step_view(m, made));
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
        blurb: str = "",
        x: float = 0.0,
        y: float = 0.0,
        reports: list[StepView] = [];

    can start with Root entry {
        # Clamp before anything else: the response envelope echoes these
        # fields, so a non-finite float would 500 the request even when the
        # stored value is clean.
        self.x = safe_coord(self.x);
        self.y = safe_coord(self.y);
        if self.step_id {
            target = resolve(self.step_id);
            if isinstance(target, WorkflowStep) and owned(here, target) {
                visit [target];
            }
        } elif self.name.strip() {
            visit steps_box(here);
        }
    }

    can update with WorkflowStep entry {
        if self.name.strip() {
            here.name = self.name.strip();
        }
        kind_changed = self.kind in STEP_KINDS and self.kind != here.kind;
        if self.kind in STEP_KINDS {
            here.kind = self.kind;
        }
        if kind_changed {
            restatus_tasks(root, here);
        }
        if self.color {
            here.color = self.color;
        }
        if self.owner {
            here.owner = self.owner.strip();
        }
        if self.blurb {
            here.blurb = self.blurb.strip();
        }
        here.updated_at = now_iso();
        report step_view(here, steps_of(root));
        disengage;
    }

    can create with WorkflowSteps entry {
        stamp = now_iso();
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
            blurb=self.blurb.strip(),
            x=self.x,
            y=self.y,
            sort_order=peak + 1024.0,
            created_at=stamp,
            updated_at=stamp
        );
        on_attached(root, fresh);
        report step_view(fresh, [here-->[?:WorkflowStep]]);
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
        report step_view(here, steps_of(root));
        disengage;
    }
}


walker SetStepRules(find_step) {
    """The step's entry rules, both sent every time: a task lands here only
    with a due date (`needs_due_date`) and a linked PR (`needs_pr`). Tasks
    already sitting here stay; the rules gate the next move in."""
    has needs_due_date: bool = False,
        needs_pr: bool = False,
        reports: list[StepView] = [];

    can apply with WorkflowStep entry {
        here.needs_due_date = self.needs_due_date;
        here.needs_pr = self.needs_pr;
        here.updated_at = now_iso();
        report step_view(here, steps_of(root));
        disengage;
    }
}


walker DeleteStep(find_step) {
    """Removes the step and every transition into it (its own go with it);
    any task on it falls back to its status. Refuses to remove the LAST start
    or done step: an org with no way in or out has a board work cannot leave."""
    has reports: list[dict[str, any]] = [];

    can remove with WorkflowStep entry {
        # `here` is the step; `root` is the caller's own root.
        holder = root;
        kind = here.kind;
        if kind == "start" or kind == "done" {
            siblings = 0;
            for s in steps_of(holder) {
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
                        "that kind first, then delete this one."
                    )
                };
                disengage;
            }
        }
        gone = jid(here);
        # Tasks keep their status, so they land by kind rather than vanishing
        # into whichever column happens to be first.
        for t in tasks_on_step(holder, gone) {
            t.step_id = "";
        }
        # An id in a field does not die with its node the way an edge did.
        for s in steps_of(holder) {
            kept = [
                t
                for t in s.transitions
                if t["to"] != gone
            ];
            if len(kept) != len(s.transitions) {
                s.transitions = kept;
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

    can start with Root entry {
        visit [here-->[?:WorkflowSteps]] else {
            report {"ok": True, "deleted": 0};
        }
    }

    can wipe with WorkflowSteps entry {
        steps = [here-->[?:WorkflowStep]];
        gone: list[str] = [];
        for s in steps {
            gone.append(jid(s));
        }
        for t in tasks_on_steps(root, gone) {
            t.step_id = "";
        }
        for s in steps {
            del s;
        }
        here.template_key = "";
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
        # "issue" or "pr" (CARRY_KINDS); anything else is stored as untagged.
        carries: str = "",
        # What moves a task across on its own (TRANSITION_TRIGGERS), and the
        # label a "label" trigger waits for.
        trigger: str = "",
        trigger_label: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
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
        visit [source];
    }

    # `here` is the source step; the target was owned-checked above.
    can link with WorkflowStep entry {
        source = here;
        target = resolve(self.to_id);
        if not isinstance(target, WorkflowStep) {
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
        fresh = transition(
            jid(target), self.label, self.carries, self.trigger, self.trigger_label
        );
        to = fresh["to"];
        # Re-drawing an arrow is how its label gets edited: a non-empty
        # label, tag or trigger replaces the stored one, an empty one keeps it.
        kept: list[dict[str, str]] = [];
        duplicate = False;
        for t in source.transitions {
            if t["to"] == to {
                duplicate = True;
                had = transition(
                    to,
                    t["label"],
                    t["carries"],
                    t.get("trigger", ""),
                    t.get("trigger_label", "")
                );
                kept.append(
                    transition(
                        to,
                        fresh["label"] or had["label"],
                        fresh["carries"] or had["carries"],
                        fresh["trigger"] or had["trigger"],
                        fresh["trigger_label"] or had["trigger_label"]
                    )
                );
            } else {
                kept.append(t);
            }
        }
        if not duplicate {
            kept.append(fresh);
        }
        source.transitions = kept;
        report {"ok": True, "linked": True, "duplicate": duplicate};
    }
}


walker LabelTransition {
    """Set or clear what has to be true to cross an existing transition, and
    what it carries and what moves a task across on its own. Unlike
    LinkTransition, empty here means CLEAR, the only way to take the wording
    or the trigger off an arrow without deleting it. The editor saves every
    field together, so all are always sent."""
    has from_id: str = "",
        to_id: str = "",
        label: str = "",
        carries: str = "",
        trigger: str = "",
        trigger_label: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
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
        visit [source];
    }

    # `here` is the source step; the target was owned-checked above.
    can relabel with WorkflowStep entry {
        source = here;
        target = resolve(self.to_id);
        if not isinstance(target, WorkflowStep) {
            disengage;
        }
        fresh = transition(
            jid(target), self.label, self.carries, self.trigger, self.trigger_label
        );
        found = False;
        kept: list[dict[str, str]] = [];
        for t in source.transitions {
            if t["to"] == fresh["to"] {
                found = True;
                kept.append(fresh);
            } else {
                kept.append(t);
            }
        }
        if not found {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        # A label trigger with no label to wait for would never fire.
        if fresh["trigger"] == "label" and not fresh["trigger_label"] {
            report {
                "ok": False,
                "error": "match_required",
                "message": "Name the label that moves work along this arrow."
            };
            disengage;
        }
        source.transitions = kept;
        report {
            "ok": True,
            "label": fresh["label"],
            "carries": fresh["carries"],
            "trigger": fresh["trigger"],
            "trigger_label": fresh["trigger_label"]
        };
    }
}


walker UnlinkTransition {
    has from_id: str = "",
        to_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
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
        visit [source];
    }

    # `here` is the source step; the target was owned-checked above.
    can unlink with WorkflowStep entry {
        source = here;
        target = resolve(self.to_id);
        if not isinstance(target, WorkflowStep) {
            disengage;
        }
        to = jid(target);
        source.transitions = [
            t
            for t in source.transitions
            if t["to"] != to
        ];
        report {"ok": True, "unlinked": True};
    }
}
