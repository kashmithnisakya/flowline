"""Project walkers: CRUD plus member assignment edges."""

import from models { Project, Member, OnProject, resolve, owned }
import from walkers.util { caller_level, level_rank, attach_stamp }

# ----------------------------------------------------------------- projects

walker ListProjects {
    has reports: list[list[Project]] = [];

    # Rows live in a local, never a `has` field: a walker's public fields
    # are serialised into the response beside the report, so an accumulator
    # field would ship the whole list twice.
    can gather with Root entry {
        rows = [here-->[?:Project]];
        rows.sort(key=lambda (p: Project) { p.name; });
        report rows;
    }
}

walker SaveProject {
    """Empty project_id creates; otherwise updates the addressed Project."""
    has project_id: str = "",
        name: str = "",
        description: str = "",
        reports: list[Project] = [];

    can save with Root entry {
        # Members below manager cannot manage projects; silent no-op like
        # every other unauthorized mutation.
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        if not self.name.strip() {
            disengage;
        }
        if self.project_id {
            target = resolve(self.project_id);
            if isinstance(target, Project) and owned(here, target) {
                target.name = self.name.strip();
                target.description = self.description;
                report target;
            }
        } else {
            fresh = here ++> Project(
                name=self.name.strip(), description=self.description
            );
            attach_stamp(here, fresh);
            report fresh;
        }
    }
}

walker ArchiveProject {
    """active=False, tasks and history keep pointing at it."""
    has project_id: str;

    can archive with Root entry {
        # Members below manager cannot manage projects.
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        target = resolve(self.project_id);
        if isinstance(target, Project) and owned(here, target) {
            target.active = False;
            report {"archived": self.project_id};
        }
    }
}

walker AssignToProject {
    has member_id: str,
        project_id: str;

    can assign with Root entry {
        # Members below manager cannot manage projects.
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if not owned(here, m) or not owned(here, p) {
            disengage;
        }
        if not [edge m->:OnProject:->p] {
            m +>:OnProject():+> p;
            # Re-stamp so linked members' ACL grants cover the fresh edge.
            attach_stamp(here, m);
        }
        report {"assigned": True};
    }
}

walker UnassignFromProject {
    has member_id: str,
        project_id: str;

    can unassign with Root entry {
        # Members below manager cannot manage projects.
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if not owned(here, m) or not owned(here, p) {
            disengage;
        }
        for e in [edge m->:OnProject:->p] {
            del e;
        }
        report {"unassigned": True};
    }
}
