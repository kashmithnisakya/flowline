"""Roadmap walkers: the per-project milestone API.

Pure graph work — no HTTP, no Python imports beyond the shared timestamp
helper. A milestone hangs off the caller's root like every other archetype
and points at exactly one project through OnRoadmap, so the one-hop
ownership check keeps working unchanged.
"""

import from models {
    Project, Task, Milestone, MilestoneView, TaskView,
    OnRoadmap, InMilestone, ForProject,
    milestone_view, resolve, on_attached, owned
}
import from walkers.util { now_iso }
import from walkers.tasks { find_task }
import from constants { MILESTONE_STATUSES }

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
