"""Roadmap walkers: the per-project milestone API.

Pure graph work — no HTTP, no Python imports beyond the shared timestamp
helper. A milestone hangs off the caller's root like every other archetype
and points at exactly one project through OnRoadmap, so the one-hop
ownership check keeps working unchanged.
"""

import from models {
    Project, Task, Milestone, MilestoneView, TaskView,
    OnRoadmap, InMilestone, ForProject, LeadsTo,
    milestone_view, resolve, on_attached, owned
}
import from walkers.util { now_iso }
import from walkers.tasks { find_task }
import from constants { MILESTONE_STATUSES }

# ------------------------------------------------------------------- layout

# Better of two steps for spine purposes: the one that can reach furthest,
# then the one feeding the most downstream work, then the order the user set.
# Falling back to the jid keeps the picture identical between reloads.
def spine_better(
    a: str, b: str, heights: dict[str, int], weights: dict[str, int],
    by_id: dict[str, MilestoneView]
) -> bool {
    if heights[a] != heights[b] {
        return heights[a] > heights[b];
    }
    if weights[a] != weights[b] {
        return weights[a] > weights[b];
    }
    if by_id[a].sort_order != by_id[b].sort_order {
        return by_id[a].sort_order < by_id[b].sort_order;
    }
    return a < b;
}


def lowest_sort_order(members: list[MilestoneView]) -> float {
    lowest = members[0].sort_order;
    for m in members {
        if m.sort_order < lowest {
            lowest = m.sort_order;
        }
    }
    return lowest;
}


# Place one connected group of steps. Returns its deepest row so the caller
# can stack the next group below it.
def layout_component(
    members: list[MilestoneView], by_id: dict[str, MilestoneView],
    comp_index: int, row_offset: int
) -> int {
    ids: list[str] = [];
    for m in members {
        ids.append(m.id);
    }
    indeg: dict[str, int] = {};
    for m in members {
        indeg[m.id] = 0;
    }
    for m in members {
        for nid in m.next_ids {
            if nid in ids {
                indeg[nid] = indeg[nid] + 1;
            }
        }
    }
    ranked = [m for m in members];
    ranked.sort(key=lambda (m: MilestoneView) { m.sort_order; });
    # Seeding in sort_order keeps the whole pass deterministic.
    roots: list[str] = [];
    for m in ranked {
        if indeg[m.id] == 0 {
            roots.append(m.id);
        }
    }
    queue = [r for r in roots];
    order: list[str] = [];
    at = 0;
    while at < len(queue) {
        current = queue[at];
        at = at + 1;
        order.append(current);
        for nid in by_id[current].next_ids {
            if nid in ids {
                indeg[nid] = indeg[nid] - 1;
                if indeg[nid] == 0 {
                    queue.append(nid);
                }
            }
        }
    }
    # Longest path, not shortest: it is what guarantees depth(child) is always
    # greater than depth(parent), so every arrow drawn points downward and the
    # renderer never has to handle a sideways or upward edge.
    depths: dict[str, int] = {};
    for m in members {
        depths[m.id] = 0;
    }
    for sid in order {
        for nid in by_id[sid].next_ids {
            if nid in ids and depths[sid] + 1 > depths[nid] {
                depths[nid] = depths[sid] + 1;
            }
        }
    }
    # Height (how many rows this step can still reach) and weight (how much
    # work hangs off it), both settled in one reverse pass over the
    # topological order.
    heights: dict[str, int] = {};
    weights: dict[str, int] = {};
    for m in members {
        heights[m.id] = 0;
        weights[m.id] = 1;
    }
    back = len(order) - 1;
    while back >= 0 {
        sid = order[back];
        back = back - 1;
        tallest = -1;
        total = 1;
        for nid in by_id[sid].next_ids {
            if nid in ids {
                if heights[nid] > tallest {
                    tallest = heights[nid];
                }
                total = total + weights[nid];
            }
        }
        heights[sid] = tallest + 1;
        weights[sid] = total;
    }
    # The spine is ONE real chain, walked edge by edge from the best root.
    # Picking the best step at each depth independently looked equivalent and
    # is not: it can hop between chains that share no arrow, drawing a solid
    # centre line between two unrelated steps.
    on_spine: dict[str, bool] = {};
    for m in members {
        on_spine[m.id] = False;
    }
    head = "";
    for rid in roots {
        if not head {
            head = rid;
        } elif spine_better(rid, head, heights, weights, by_id) {
            head = rid;
        }
    }
    cursor = head;
    while cursor {
        on_spine[cursor] = True;
        nxt = "";
        for nid in by_id[cursor].next_ids {
            if nid not in ids {
                continue;
            }
            if not nxt {
                nxt = nid;
            } elif spine_better(nid, nxt, heights, weights, by_id) {
                nxt = nid;
            }
        }
        cursor = nxt;
    }
    deepest = 0;
    for m in members {
        if depths[m.id] > deepest {
            deepest = depths[m.id];
        }
        m.component = comp_index;
        m.depth = depths[m.id] + row_offset;
        if on_spine[m.id] {
            m.lane = 0;
        }
    }
    # Branch lanes, row by row. Every parent is already placed because
    # longest-path depth puts it strictly above its children.
    row = 0;
    while row <= deepest {
        peers: list[MilestoneView] = [];
        for m in ranked {
            if depths[m.id] == row and not on_spine[m.id] {
                peers.append(m);
            }
        }
        left = 0;
        right = 0;
        for p in peers {
            par = "";
            for pid in p.prev_ids {
                if pid not in ids {
                    continue;
                }
                if not par {
                    par = pid;
                } elif depths[pid] > depths[par] {
                    par = pid;
                } elif depths[pid] == depths[par]
                    and spine_better(pid, par, heights, weights, by_id) {
                    par = pid;
                }
            }
            # A sub-tree stays on its parent's side of the page as it
            # descends; anything hanging off the spine alternates so the
            # picture stays balanced.
            side = 0;
            if par {
                if by_id[par].lane < 0 {
                    side = -1;
                } elif by_id[par].lane > 0 {
                    side = 1;
                }
            }
            if side == 0 {
                side = -1 if left <= right else 1;
            }
            if side < 0 {
                left = left + 1;
                p.lane = 0 - left;
            } else {
                right = right + 1;
                p.lane = right;
            }
        }
        row = row + 1;
    }
    return deepest;
}


# Place every step on a grid the client can draw directly, in the shape of a
# roadmap: one vertical spine per connected group, with branches hanging off
# either side.
#
# `depth` is the row and `lane` the column (0 on the spine, alternating
# outward for branches). Steps with no arrows at all get depth -1: they are
# not on the roadmap yet, and the client shows them in a tray underneath
# rather than as a column of one-step groups.
def layout_steps(views: list[MilestoneView]) -> None {
    by_id: dict[str, MilestoneView] = {};
    for v in views {
        by_id[v.id] = v;
    }
    grid: list[MilestoneView] = [];
    for v in views {
        linked = False;
        for pid in v.prev_ids {
            if pid in by_id {
                linked = True;
            }
        }
        for nid in v.next_ids {
            if nid in by_id {
                linked = True;
            }
        }
        if linked {
            grid.append(v);
        } else {
            v.depth = -1;
            v.lane = 0;
            v.component = -1;
        }
    }
    if not grid {
        seeded = [v for v in views];
        seeded.sort(key=lambda (m: MilestoneView) { m.sort_order; });
        for (i, v) in enumerate(seeded) {
            v.depth = 0;
            v.component = 0;
            # 0, 1, -1, 2, -2, ... so the first step keeps the spine and the
            # rest alternate outward, the same shape a real row gets.
            out = (i + 1) // 2;
            v.lane = out if i % 2 == 1 else 0 - out;
        }
        return;
    }
    # Weakly connected groups: follow arrows in both directions, because two
    # steps feeding the same third one belong on the same picture.
    seen: dict[str, bool] = {};
    groups: list[list[MilestoneView]] = [];
    for v in grid {
        if v.id in seen {
            continue;
        }
        members: list[MilestoneView] = [];
        frontier: list[str] = [v.id];
        seen[v.id] = True;
        at = 0;
        while at < len(frontier) {
            current = frontier[at];
            at = at + 1;
            members.append(by_id[current]);
            for nid in by_id[current].prev_ids + by_id[current].next_ids {
                if nid in by_id and nid not in seen {
                    seen[nid] = True;
                    frontier.append(nid);
                }
            }
        }
        groups.append(members);
    }
    # Order groups by their earliest step rather than by size, so adding an
    # arrow does not make whole sections of the page jump.
    ordered: list[list[MilestoneView]] = [];
    rest = [g for g in groups];
    while rest {
        best = 0;
        for (i, g) in enumerate(rest) {
            if lowest_sort_order(g) < lowest_sort_order(rest[best]) {
                best = i;
            }
        }
        ordered.append(rest[best]);
        rest = [g for (i, g) in enumerate(rest) if i != best];
    }
    row_offset = 0;
    for (index, members) in enumerate(ordered) {
        deepest = layout_component(members, by_id, index, row_offset);
        # One blank row between groups so they read as separate roadmaps.
        row_offset = row_offset + deepest + 2;
    }
    # A step is startable when every arrow into it comes from finished work.
    for v in views {
        waiting = 0;
        for pid in v.prev_ids {
            if pid in by_id and by_id[pid].status != "Done" {
                waiting = waiting + 1;
            }
        }
        v.blocked_by = waiting;
        v.ready = waiting == 0 and v.status != "Done";
    }
}


# ---------------------------------------------------------------- milestones

walker ListMilestones {
    """Every milestone on the caller's roadmap, optionally one project's.

    The project filter compares jid STRINGS against the OnRoadmap target;
    it never resolves project_id. A foreign or stale id therefore matches
    nothing and returns an empty list, rather than silently widening to
    every milestone the caller owns."""
    has project_id: str = "",
        results: list[MilestoneView] = [],
        reports: list[list[MilestoneView]] = [];

    can start with Root entry {
        visit [here-->[?:Milestone]];
    }

    can gather with Milestone entry {
        view = milestone_view(here);
        if not self.project_id or view.project_id == self.project_id {
            self.results.append(view);
        }
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (m: MilestoneView) { m.sort_order; });
        # Depth and lane only mean anything within one project's roadmap, so
        # lay each project's steps out on their own grid.
        seen: list[str] = [];
        for m in self.results {
            if m.project_id not in seen {
                seen.append(m.project_id);
            }
        }
        for pid in seen {
            layout_steps([m for m in self.results if m.project_id == pid]);
        }
        report self.results;
    }
}

walker SaveMilestone {
    """Empty milestone_id creates; otherwise updates the addressed one.

    Both the milestone and the project are ownership-checked independently:
    resolving a jid is not authorization."""
    has milestone_id: str = "",
        project_id: str = "",
        title: str = "",
        description: str = "",
        start_date: str = "",
        due_date: str = "",
        status: str = "Planned",
        color: str = "",
        reports: list[MilestoneView] = [];

    can save with Root entry {
        if not self.title.strip() {
            disengage;
        }
        # ISO dates compare correctly as strings; an inverted range is a
        # typo, not a roadmap.
        if self.start_date and self.due_date and self.due_date < self.start_date {
            disengage;
        }
        state = self.status if self.status in MILESTONE_STATUSES else "Planned";
        stamp = now_iso();
        proj = resolve(self.project_id);
        if self.milestone_id {
            target = resolve(self.milestone_id);
            if not isinstance(target, Milestone) or not owned(here, target) {
                disengage;
            }
            target.title = self.title.strip();
            target.description = self.description;
            target.start_date = self.start_date;
            target.due_date = self.due_date;
            target.status = state;
            target.color = self.color;
            target.updated_at = stamp;
            if isinstance(proj, Project) and owned(here, proj) {
                current = [target ->:OnRoadmap:->];
                if not current or jid(current[0]) != self.project_id {
                    for e in [edge target ->:OnRoadmap:->] {
                        del e;
                    }
                    target +>:OnRoadmap():+> proj;
                    # Tasks stay with their own project, so anything that
                    # followed the milestone across now belongs elsewhere.
                    for t in [target<-:InMilestone:<-[?:Task]] {
                        owning = [t ->:ForProject:->];
                        if owning and jid(owning[0]) != self.project_id {
                            for e2 in [edge t ->:InMilestone:->] {
                                del e2;
                            }
                        }
                    }
                }
            }
            report milestone_view(target);
        } elif isinstance(proj, Project) and owned(here, proj) {
            peak = 0.0;
            for m in [here-->[?:Milestone]] {
                on = [m ->:OnRoadmap:->];
                if on and jid(on[0]) == self.project_id and m.sort_order > peak {
                    peak = m.sort_order;
                }
            }
            fresh = here ++> Milestone(
                title=self.title.strip(), description=self.description,
                start_date=self.start_date, due_date=self.due_date,
                status=state, color=self.color,
                sort_order=peak + 1024.0, created_at=stamp, updated_at=stamp
            );
            on_attached(here, fresh);
            fresh +>:OnRoadmap():+> proj;
            report milestone_view(fresh);
        }
    }
}

walker find_milestone {
    """Lookup base: resolve the jid once, verify org parentage, then visit.
    Mirrors find_task — every milestone mutation goes through it."""
    has milestone_id: str = "";

    can locate with Root entry {
        target = resolve(self.milestone_id);
        if isinstance(target, Milestone) and owned(here, target) {
            visit [target];
        }
    }
}

walker DeleteMilestone(find_milestone) {
    """Removes the phase, not the work: incoming InMilestone edges die with
    the node and the tasks themselves survive, unattached."""

    can remove with Milestone entry {
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}

walker ReorderMilestone(find_milestone) {
    """Server-authoritative ordering. Empty after_id moves to the front,
    otherwise the milestone lands immediately after that sibling."""
    has after_id: str = "",
        reports: list[MilestoneView] = [];

    can reorder with Milestone entry {
        owners = [here<--];
        holder = owners[0];
        mine = [here ->:OnRoadmap:->];
        if not mine {
            disengage;
        }
        pid = jid(mine[0]);
        siblings: list[Milestone] = [];
        for m in [holder-->[?:Milestone]] {
            on = [m ->:OnRoadmap:->];
            if on and jid(on[0]) == pid and jid(m) != jid(here) {
                siblings.append(m);
            }
        }
        siblings.sort(key=lambda (m: Milestone) { m.sort_order; });
        if not self.after_id {
            head = siblings[0].sort_order if siblings else 2048.0;
            here.sort_order = head / 2.0;
        } else {
            anchor_at = -1;
            for (i, m) in enumerate(siblings) {
                if jid(m) == self.after_id {
                    anchor_at = i;
                }
            }
            # after_id must be an owned milestone on the SAME project, else
            # the move is meaningless — leave the order untouched.
            if anchor_at < 0 {
                disengage;
            }
            anchor = siblings[anchor_at].sort_order;
            if anchor_at + 1 < len(siblings) {
                here.sort_order = (anchor + siblings[anchor_at + 1].sort_order) / 2.0;
            } else {
                here.sort_order = anchor + 1024.0;
            }
        }
        here.updated_at = now_iso();
        report milestone_view(here);
        disengage;
    }
}

# Would an arrow from `source` to `target` close a loop? Walk forward from
# target; reaching source means target already leads back round to it. Plain
# breadth-first over LeadsTo, so it costs one pass over the reachable set.
def would_cycle(source: Milestone, target: Milestone) -> bool {
    if jid(source) == jid(target) {
        return True;
    }
    seen: list[str] = [jid(target)];
    frontier: list[Milestone] = [target];
    at = 0;
    while at < len(frontier) {
        current = frontier[at];
        at = at + 1;
        for nxt in [current ->:LeadsTo:->] {
            if jid(nxt) == jid(source) {
                return True;
            }
            if jid(nxt) not in seen {
                seen.append(jid(nxt));
                frontier.append(nxt);
            }
        }
    }
    return False;
}


walker LinkSteps {
    """Draw an arrow: from_id leads to to_id.

    Both ends are owned-checked independently, must sit on the same project,
    and the arrow is refused if it would close a loop. A roadmap that can
    reach itself has no depth, so the layout and the ready signal would both
    become meaningless."""
    has from_id: str = "",
        to_id: str = "",
        reports: list[dict[str, any]] = [];

    can link with Root entry {
        source = resolve(self.from_id);
        target = resolve(self.to_id);
        if not isinstance(source, Milestone) or not owned(here, source) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if not isinstance(target, Milestone) or not owned(here, target) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        source_project = [source ->:OnRoadmap:->];
        target_project = [target ->:OnRoadmap:->];
        if not source_project or not target_project {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if jid(source_project[0]) != jid(target_project[0]) {
            report {
                "ok": False, "error": "different_project",
                "message": "Steps can only connect within one project's roadmap."
            };
            disengage;
        }
        if jid(source) == jid(target) {
            report {
                "ok": False, "error": "self_link",
                "message": "A step cannot lead to itself."
            };
            disengage;
        }
        if [edge source ->:LeadsTo:-> target] {
            report {"ok": True, "linked": True, "duplicate": True};
            disengage;
        }
        if would_cycle(source, target) {
            report {
                "ok": False, "error": "cycle",
                "message": "That arrow would loop the roadmap back on itself."
            };
            disengage;
        }
        source +>:LeadsTo():+> target;
        report {"ok": True, "linked": True};
    }
}


walker UnlinkSteps {
    has from_id: str = "",
        to_id: str = "",
        reports: list[dict[str, any]] = [];

    can unlink with Root entry {
        source = resolve(self.from_id);
        target = resolve(self.to_id);
        if not isinstance(source, Milestone) or not owned(here, source) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        if not isinstance(target, Milestone) or not owned(here, target) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        for e in [edge source ->:LeadsTo:-> target] {
            del e;
        }
        report {"ok": True, "unlinked": True};
    }
}


walker SetTaskMilestone(find_task) {
    """Attach a task to a milestone, or detach it with an empty id.

    A task carries at most one InMilestone edge, and only to a milestone on
    its own project — a cross-project attach is a no-op, which the client
    cannot trigger anyway because it only offers the project's own
    milestones."""
    has milestone_id: str = "",
        reports: list[TaskView] = [];

    can attach with Task entry {
        # In a Task entry ability `here` is the task; the caller's root is
        # one hop back, and that is what ownership is measured against.
        owners = [here<--];
        holder = owners[0];
        if not self.milestone_id {
            for e in [edge here ->:InMilestone:->] {
                del e;
            }
            here.updated_at = now_iso();
            report here.to_view();
            disengage;
        }
        target = resolve(self.milestone_id);
        if not isinstance(target, Milestone) or not owned(holder, target) {
            disengage;
        }
        stone_projects = [target ->:OnRoadmap:->];
        if not stone_projects {
            disengage;
        }
        task_projects = [here ->:ForProject:->];
        if task_projects and jid(task_projects[0]) != jid(stone_projects[0]) {
            disengage;
        }
        if not task_projects {
            here +>:ForProject():+> stone_projects[0];
        }
        for e in [edge here ->:InMilestone:->] {
            del e;
        }
        here +>:InMilestone():+> target;
        here.updated_at = now_iso();
        report here.to_view();
        disengage;
    }
}
